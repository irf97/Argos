defmodule ArgosWeb.Api.ApprovalController do
  use ArgosWeb, :controller

  alias Argos.Approvals

  def index(conn, params) do
    opts =
      case Map.get(params, "status") do
        nil -> []
        status -> [status: status]
      end

    approvals = Approvals.list_approvals(opts)
    json(conn, %{approvals: Enum.map(approvals, &approval_json/1)})
  end

  def approve(conn, %{"id" => id} = params) do
    decide(conn, id, params, &Approvals.approve/2)
  end

  def reject(conn, %{"id" => id} = params) do
    decide(conn, id, params, &Approvals.reject/2)
  end

  defp decide(conn, id, params, decision_fun) do
    case decision_fun.(id, params) do
      {:ok, approval, nil} ->
        json(conn, %{approval: approval_json(approval)})

      {:ok, approval, canon} ->
        json(conn, %{approval: approval_json(approval), canon: canon_json(canon)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "approval not found"})

      {:error, :already_decided} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "approval already decided"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  defp approval_json(approval) do
    %{
      id: approval.id,
      subject_type: approval.subject_type,
      subject_id: approval.subject_id,
      action: approval.action,
      risk_level: approval.risk_level,
      status: approval.status,
      proposal: approval.proposal,
      reason: approval.reason,
      decided_by: approval.decided_by,
      decided_at: maybe_iso8601(approval.decided_at),
      inserted_at: DateTime.to_iso8601(approval.inserted_at)
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
      hash: canon.hash,
      status: canon.status,
      approved_by: canon.approved_by,
      approved_at: DateTime.to_iso8601(canon.approved_at)
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp maybe_iso8601(nil), do: nil
  defp maybe_iso8601(datetime), do: DateTime.to_iso8601(datetime)
end
