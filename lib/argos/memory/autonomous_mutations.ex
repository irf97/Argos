defmodule Argos.Memory.AutonomousMutations do
  @moduledoc """
  Bounded autonomous canon mutations with audit and rollback.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Argos.Intelligence.Proposal
  alias Argos.Memory.AutonomousMutation
  alias Argos.Memory.Canon
  alias Argos.Memory.Canons
  alias Argos.Memory.Events
  alias Argos.Repo

  @risk_order %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
  @protected_touches ~w(design_law schemas autonomy_policy)

  def maybe_apply(%Proposal{} = proposal) do
    case decision(proposal) do
      {:auto_apply, prior_canon, new_state, policy, trace} ->
        apply_autonomous(proposal, prior_canon, new_state, policy, trace)

      {:approval_required, reason} ->
        {:approval_required, reason}
    end
  end

  def list_recent(limit \\ 10) do
    AutonomousMutation
    |> order_by([mutation], desc: mutation.applied_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_by_proposal_id(proposal_id),
    do: Repo.get_by(AutonomousMutation, proposal_id: proposal_id)

  def rollback(proposal_id, attrs \\ %{}) do
    operator = Canons.map_value(attrs, "operator") || "operator"
    reason = Canons.map_value(attrs, "reason") || "operator rollback"
    now = DateTime.utc_now()

    with %AutonomousMutation{} = mutation <- get_by_proposal_id(proposal_id),
         :ok <- ensure_not_rolled_back(mutation),
         :ok <- ensure_not_expired(mutation, now),
         prior_canon <- Repo.get!(Canon, mutation.prior_canon_id),
         latest_canon <- Canons.get_canon(mutation.canon),
         {:ok, rollback_canon} <-
           Canons.commit_rollback_canon(prior_canon, latest_canon, %{
             "operator" => operator,
             "reason" => reason
           }),
         {:ok, mutation} <-
           mutation
           |> AutonomousMutation.rollback_changeset(%{
             rolled_back_at: now,
             rollback_reason: reason,
             rollback_canon_id: rollback_canon.id
           })
           |> Repo.update(),
         {:ok, proposal} <- mark_proposal_status(mutation.proposal_id, "rolled_back") do
      {:ok, mutation, rollback_canon, proposal}
    else
      nil -> {:error, :autonomous_mutation_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decision(%Proposal{} = proposal) do
    prior_canon = Canons.get_canon(proposal.canon)

    cond do
      is_nil(prior_canon) ->
        {:approval_required, :canon_not_found}

      protected_touch?(proposal) ->
        {:approval_required, :protected_touch}

      true ->
        policy = prior_canon.autonomy_policy || Canon.default_autonomy_policy()
        action = proposal.proposed_action || %{}
        kind = Map.get(action, "kind") || proposal.type

        with :ok <- mode_allows(policy),
             :ok <- proposal_kind_allowed(policy, kind),
             :ok <- severity_allowed(policy, proposal.risk_level),
             :ok <- daily_cap_available(policy, proposal.canon),
             :ok <- invocation_evidence_allowed(policy, action),
             :ok <- confidence_allowed(policy, action),
             {:ok, new_state} <- proposed_state(prior_canon.state, action) do
          trace = %{
            "proposal_kind" => kind,
            "risk_level" => proposal.risk_level,
            "mode" => Map.get(policy, "mode"),
            "checks" => [
              "mode_allows",
              "proposal_kind_allowed",
              "severity_allowed",
              "daily_cap_available",
              "invocation_evidence_allowed",
              "confidence_allowed"
            ]
          }

          {:auto_apply, prior_canon, new_state, policy, trace}
        else
          {:error, reason} -> {:approval_required, reason}
        end
    end
  end

  defp apply_autonomous(proposal, prior_canon, new_state, policy, trace) do
    with {:ok, new_canon} <- Canons.commit_autonomous_canon(proposal, new_state, policy),
         now <- DateTime.utc_now(),
         {:ok, mutation} <-
           %AutonomousMutation{}
           |> AutonomousMutation.changeset(%{
             proposal_id: proposal.id,
             canon: proposal.canon,
             prior_canon_id: prior_canon.id,
             new_canon_id: new_canon.id,
             prior_canon_version: prior_canon.version,
             new_canon_version: new_canon.version,
             autonomy_policy_snapshot: policy,
             reasoning_trace: trace,
             applied_at: now,
             rollback_expires_at: DateTime.add(now, 24 * 60 * 60, :second)
           })
           |> Repo.insert(),
         {:ok, _event} <-
           Events.append_event(%{
             kind: "autonomous_mutation_applied",
             canon: proposal.canon,
             source: "argos",
             payload: %{
               "proposal_id" => proposal.id,
               "mutation_id" => mutation.id,
               "prior_canon_version" => prior_canon.version,
               "new_canon_version" => new_canon.version,
               "rollback_expires_at" => DateTime.to_iso8601(mutation.rollback_expires_at)
             },
             author: "argos:auto"
           }),
         {:ok, proposal} <- mark_proposal_status(proposal.id, "auto_applied") do
      {:auto_applied, proposal, mutation}
    end
  end

  defp mode_allows(%{"mode" => "auto_apply_bounded"}), do: :ok
  defp mode_allows(%{"mode" => "auto_apply_open"}), do: :ok
  defp mode_allows(_policy), do: {:error, :require_approval}

  defp proposal_kind_allowed(%{"mode" => "auto_apply_open"}, _kind), do: :ok

  defp proposal_kind_allowed(policy, kind) do
    allowed = Map.get(policy, "allowed_proposal_kinds", [])

    if kind in allowed do
      :ok
    else
      {:error, :proposal_kind_not_allowed}
    end
  end

  defp severity_allowed(policy, severity) do
    ceiling = Map.get(policy, "severity_ceiling", "low")

    if risk_value(severity) <= risk_value(ceiling) do
      :ok
    else
      {:error, :severity_above_ceiling}
    end
  end

  defp daily_cap_available(policy, canon) do
    cap = Map.get(policy, "daily_cap", 0)
    since = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)

    count =
      AutonomousMutation
      |> where([mutation], mutation.canon == ^canon and mutation.applied_at >= ^since)
      |> Repo.aggregate(:count)

    if cap > 0 and count < cap do
      :ok
    else
      {:error, :daily_cap_reached}
    end
  end

  defp invocation_evidence_allowed(policy, action) do
    required = Map.get(policy, "min_invocation_evidence", 0)
    actual = Map.get(action, "invocation_evidence", 0)

    if actual >= required do
      :ok
    else
      {:error, :insufficient_invocation_evidence}
    end
  end

  defp confidence_allowed(policy, action) do
    required = Map.get(policy, "min_confidence", "user-confirmed")
    actual = Map.get(action, "confidence")

    cond do
      required == "evidenced-in-chat" and actual in ["evidenced-in-chat", "user-confirmed"] ->
        :ok

      required == "user-confirmed" and actual == "user-confirmed" ->
        :ok

      true ->
        {:error, :insufficient_confidence}
    end
  end

  defp proposed_state(_current_state, %{"canon_state" => state}) when is_map(state),
    do: {:ok, state}

  defp proposed_state(current_state, %{"canon_state_patch" => patch}) when is_map(patch) do
    {:ok, deep_merge(current_state || %{}, patch)}
  end

  defp proposed_state(_current_state, _action), do: {:error, :missing_canon_state_patch}

  defp protected_touch?(%Proposal{} = proposal) do
    action = proposal.proposed_action || %{}
    touches = Map.get(action, "touches", [])
    patch = Map.get(action, "canon_state_patch", %{})

    Enum.any?(touches, &(&1 in @protected_touches)) or Map.has_key?(patch, "autonomy_policy")
  end

  defp ensure_not_rolled_back(%AutonomousMutation{rolled_back_at: nil}), do: :ok
  defp ensure_not_rolled_back(_mutation), do: {:error, :already_rolled_back}

  defp ensure_not_expired(%AutonomousMutation{} = mutation, now) do
    if DateTime.compare(now, mutation.rollback_expires_at) == :gt do
      {:error, :rollback_expired}
    else
      :ok
    end
  end

  defp mark_proposal_status(proposal_id, status) do
    Proposal
    |> Repo.get!(proposal_id)
    |> change(status: status)
    |> Repo.update()
  end

  defp risk_value(risk), do: Map.get(@risk_order, risk, 99)

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(_left, right), do: right
end
