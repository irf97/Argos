defmodule Argos.Approvals do
  @moduledoc """
  Approval queue and operator decisions.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Argos.Approvals.Approval
  alias Argos.Memory.Canons
  alias Argos.Memory.Events
  alias Argos.Repo

  def create_approval(attrs) when is_map(attrs) do
    %Approval{}
    |> Approval.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, approval} ->
        Events.append_event(%{
          kind: "approval_created",
          canon: get_in(approval.proposal, ["name"]) || "operator",
          source: "argos",
          payload: %{
            "approval_id" => approval.id,
            "action" => approval.action,
            "risk_level" => approval.risk_level,
            "subject_type" => approval.subject_type
          },
          author: "operator"
        })

        {:ok, approval}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_approvals(opts \\ []) do
    Approval
    |> maybe_filter_status(Keyword.get(opts, :status))
    |> order_by([approval], desc: approval.inserted_at)
    |> Repo.all()
  end

  def get_approval!(id), do: Repo.get!(Approval, id)

  def approve(id, attrs \\ %{}) do
    decide(id, "approved", attrs)
  end

  def reject(id, attrs \\ %{}) do
    decide(id, "rejected", attrs)
  end

  defp decide(id, status, attrs) do
    decided_by = Map.get(attrs, :decided_by) || Map.get(attrs, "decided_by")

    Repo.transaction(fn ->
      approval =
        Approval
        |> where([approval], approval.id == ^id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      cond do
        is_nil(approval) ->
          Repo.rollback(:not_found)

        approval.status != "pending" ->
          Repo.rollback(:already_decided)

        not is_binary(decided_by) or decided_by == "" ->
          approval
          |> change()
          |> add_error(:decided_by, "is required")
          |> then(&Repo.rollback({:error, &1}))

        true ->
          approval =
            approval
            |> Approval.decision_changeset(%{
              status: status,
              decided_by: decided_by,
              decided_at: DateTime.utc_now()
            })
            |> Repo.update!()

          Events.append_event(%{
            kind: "approval_decided",
            canon: get_in(approval.proposal, ["name"]) || "operator",
            source: "argos",
            payload: %{
              "approval_id" => approval.id,
              "action" => approval.action,
              "status" => approval.status
            },
            author: decided_by
          })

          if status == "approved" and approval.action == "canon_commit" do
            case Canons.commit_approved_canon(approval) do
              {:ok, canon} -> {approval, canon}
              {:error, reason} -> Repo.rollback(reason)
            end
          else
            {approval, nil}
          end
      end
    end)
    |> case do
      {:ok, {approval, result}} -> {:ok, approval, result}
      {:error, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [approval], approval.status == ^status)
  end
end
