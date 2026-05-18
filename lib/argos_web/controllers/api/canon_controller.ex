defmodule ArgosWeb.Api.CanonController do
  use ArgosWeb, :controller

  alias Argos.Memory.Canons

  def show(conn, %{"name" => name}) do
    case Canons.get_canon(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "canon not found"})

      canon ->
        json(conn, %{canon: canon_json(canon)})
    end
  end

  def draft(conn, %{"name" => name} = params) do
    case Canons.draft_canon(name, params) do
      {:ok, approval} ->
        conn
        |> put_status(:created)
        |> json(%{approval: approval_json(approval)})

      {:error, :invalid_state} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{state: ["must be a map"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
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

  defp approval_json(approval) do
    %{
      id: approval.id,
      subject_type: approval.subject_type,
      subject_id: approval.subject_id,
      action: approval.action,
      risk_level: approval.risk_level,
      status: approval.status,
      proposal: approval.proposal,
      reason: approval.reason
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
