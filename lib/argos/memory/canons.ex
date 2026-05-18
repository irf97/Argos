defmodule Argos.Memory.Canons do
  @moduledoc """
  Immutable canon versioning behind operator approvals.
  """

  import Ecto.Query

  alias Argos.Approvals
  alias Argos.Approvals.Approval
  alias Argos.Intelligence.Proposal
  alias Argos.Kernel.Hashing
  alias Argos.Memory.Canon
  alias Argos.Memory.Events
  alias Argos.Repo

  def draft_canon(name, attrs) when is_binary(name) and is_map(attrs) do
    state = Map.get(attrs, :state) || Map.get(attrs, "state")
    author = Map.get(attrs, :author) || Map.get(attrs, "author") || "operator"
    reason = Map.get(attrs, :reason) || Map.get(attrs, "reason")

    with true <- is_map(state) do
      latest = get_canon(name)
      version = if latest, do: latest.version + 1, else: 1
      ancestor_hash = if latest, do: latest.hash

      autonomy_policy =
        Map.get(attrs, :autonomy_policy) ||
          Map.get(attrs, "autonomy_policy") ||
          if(latest, do: latest.autonomy_policy, else: Canon.default_autonomy_policy())

      subject_id = Ecto.UUID.generate()

      proposal = %{
        "name" => name,
        "version" => version,
        "state" => state,
        "ancestor_hash" => ancestor_hash,
        "autonomy_policy" => autonomy_policy
      }

      case Approvals.create_approval(%{
             subject_type: "canon_draft",
             subject_id: subject_id,
             action: "canon_commit",
             risk_level: "medium",
             status: "pending",
             proposal: proposal,
             reason: reason
           }) do
        {:ok, approval} ->
          Events.append_event(%{
            kind: "canon_draft",
            canon: name,
            source: "argos",
            payload: %{
              "approval_id" => approval.id,
              "proposed_version" => version,
              "proposal_hash" => Hashing.sha256(proposal)
            },
            author: author
          })

          {:ok, approval}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      false -> {:error, :invalid_state}
    end
  end

  def get_canon(name) when is_binary(name) do
    Canon
    |> where([canon], canon.name == ^name and canon.status == "approved")
    |> order_by([canon], desc: canon.version)
    |> limit(1)
    |> Repo.one()
  end

  def list_canons do
    Canon
    |> order_by([canon], asc: canon.name, desc: canon.version)
    |> Repo.all()
  end

  def get_canon_by_id(id) when is_binary(id), do: Repo.get(Canon, id)

  def canon_hash(attrs) do
    Hashing.sha256(%{
      "ancestor_hash" => map_value(attrs, "ancestor_hash"),
      "name" => map_value(attrs, "name"),
      "autonomy_policy" => map_value(attrs, "autonomy_policy") || Canon.default_autonomy_policy(),
      "state" => map_value(attrs, "state"),
      "status" => "approved",
      "version" => map_value(attrs, "version")
    })
  end

  def commit_approved_canon(%Approval{action: "canon_commit", status: "approved"} = approval) do
    proposal = approval.proposal
    name = map_value(proposal, "name")
    state = map_value(proposal, "state")
    autonomy_policy = map_value(proposal, "autonomy_policy") || Canon.default_autonomy_policy()
    approved_by = approval.decided_by || "operator"
    approved_at = approval.decided_at || DateTime.utc_now()
    latest = get_canon(name)
    version = if latest, do: latest.version + 1, else: 1
    ancestor_hash = if latest, do: latest.hash

    attrs = %{
      name: name,
      version: version,
      state: state,
      autonomy_policy: autonomy_policy,
      ancestor_hash: ancestor_hash,
      status: "approved",
      approved_by: approved_by,
      approved_at: approved_at
    }

    attrs = Map.put(attrs, :hash, canon_hash(attrs))

    with {:ok, canon} <- %Canon{} |> Canon.changeset(attrs) |> Repo.insert(),
         {:ok, _event} <-
           Events.append_event(%{
             kind: "canon_commit",
             canon: name,
             source: "argos",
             payload: %{
               "approval_id" => approval.id,
               "canon_id" => canon.id,
               "hash" => canon.hash,
               "version" => canon.version,
               "ancestor_hash" => canon.ancestor_hash
             },
             author: approved_by
           }) do
      {:ok, canon}
    end
  end

  def commit_approved_canon(%Approval{}), do: {:error, :approval_not_committable}

  def commit_autonomous_canon(%Proposal{} = proposal, state, autonomy_policy)
      when is_map(state) do
    latest = get_canon(proposal.canon)

    if latest do
      attrs = %{
        name: proposal.canon,
        version: latest.version + 1,
        state: state,
        autonomy_policy:
          autonomy_policy || latest.autonomy_policy || Canon.default_autonomy_policy(),
        ancestor_hash: latest.hash,
        status: "approved",
        approved_by: "argos:auto",
        approved_at: DateTime.utc_now()
      }

      attrs = Map.put(attrs, :hash, canon_hash(attrs))

      with {:ok, canon} <- %Canon{} |> Canon.changeset(attrs) |> Repo.insert(),
           {:ok, _event} <-
             Events.append_event(%{
               kind: "canon_commit",
               canon: proposal.canon,
               source: "argos",
               payload: %{
                 "autonomous" => true,
                 "proposal_id" => proposal.id,
                 "canon_id" => canon.id,
                 "hash" => canon.hash,
                 "version" => canon.version,
                 "ancestor_hash" => canon.ancestor_hash
               },
               author: "argos:auto"
             }) do
        {:ok, canon}
      end
    else
      {:error, :canon_not_found}
    end
  end

  def commit_rollback_canon(prior_canon, latest_canon, attrs) do
    operator = map_value(attrs, "operator") || "operator"
    reason = map_value(attrs, "reason") || "operator rollback"

    rollback_attrs = %{
      name: latest_canon.name,
      version: latest_canon.version + 1,
      state: prior_canon.state,
      autonomy_policy: prior_canon.autonomy_policy || Canon.default_autonomy_policy(),
      ancestor_hash: latest_canon.hash,
      status: "approved",
      approved_by: operator,
      approved_at: DateTime.utc_now()
    }

    rollback_attrs = Map.put(rollback_attrs, :hash, canon_hash(rollback_attrs))

    with {:ok, canon} <- %Canon{} |> Canon.changeset(rollback_attrs) |> Repo.insert(),
         {:ok, _event} <-
           Events.append_event(%{
             kind: "autonomous_mutation_rolled_back",
             canon: canon.name,
             source: "argos",
             payload: %{
               "rollback_canon_id" => canon.id,
               "rolled_back_to_canon_id" => prior_canon.id,
               "rolled_back_to_version" => prior_canon.version,
               "reason" => reason
             },
             author: operator
           }) do
      {:ok, canon}
    end
  end

  def map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
