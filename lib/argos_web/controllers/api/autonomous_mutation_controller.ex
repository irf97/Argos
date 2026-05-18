defmodule ArgosWeb.Api.AutonomousMutationController do
  use ArgosWeb, :controller

  alias Argos.Memory.AutonomousMutations

  def index(conn, _params) do
    mutations = AutonomousMutations.list_recent()
    json(conn, %{autonomous_mutations: Enum.map(mutations, &mutation_json/1)})
  end

  def rollback(conn, %{"proposal_id" => proposal_id} = params) do
    case AutonomousMutations.rollback(proposal_id, params) do
      {:ok, mutation, rollback_canon, proposal} ->
        json(conn, %{
          autonomous_mutation: mutation_json(mutation),
          rollback_canon: canon_json(rollback_canon),
          proposal: %{id: proposal.id, status: proposal.status}
        })

      {:error, :autonomous_mutation_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "autonomous mutation not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  defp mutation_json(mutation) do
    %{
      id: mutation.id,
      proposal_id: mutation.proposal_id,
      canon: mutation.canon,
      prior_canon_id: mutation.prior_canon_id,
      new_canon_id: mutation.new_canon_id,
      prior_canon_version: mutation.prior_canon_version,
      new_canon_version: mutation.new_canon_version,
      autonomy_policy_snapshot: mutation.autonomy_policy_snapshot,
      reasoning_trace: mutation.reasoning_trace,
      applied_at: DateTime.to_iso8601(mutation.applied_at),
      rollback_expires_at: DateTime.to_iso8601(mutation.rollback_expires_at),
      rolled_back_at: maybe_iso8601(mutation.rolled_back_at),
      rollback_reason: mutation.rollback_reason,
      rollback_canon_id: mutation.rollback_canon_id
    }
  end

  defp canon_json(canon) do
    %{
      id: canon.id,
      name: canon.name,
      version: canon.version,
      state: canon.state,
      autonomy_policy: canon.autonomy_policy,
      ancestor_hash: canon.ancestor_hash,
      hash: canon.hash
    }
  end

  defp maybe_iso8601(nil), do: nil
  defp maybe_iso8601(datetime), do: DateTime.to_iso8601(datetime)
end
