defmodule ArgosWeb.Api.ArmSessionController do
  use ArgosWeb, :controller

  alias Argos.Arms

  def start(conn, params) do
    case Arms.start_session(params) do
      {:ok, session} ->
        conn
        |> put_status(:created)
        |> json(%{arm_session: session_json(session)})

      {:error, :context_pack_not_found} ->
        not_found(conn, "context pack not found")

      {:error, :context_pack_id_required} ->
        validation_error(conn, :context_pack_id, "is required")

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset_error(conn, changeset)
    end
  end

  def end_session(conn, params) do
    case Arms.end_session(params) do
      {:ok, session} ->
        json(conn, %{arm_session: session_json(session)})

      {:error, :session_not_found} ->
        not_found(conn, "arm session not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset_error(conn, changeset)
    end
  end

  defp session_json(session) do
    %{
      id: session.id,
      arm: session.arm,
      project: session.project,
      task: session.task,
      context_pack_id: session.context_pack_id,
      started_at: DateTime.to_iso8601(session.started_at),
      ended_at: maybe_iso8601(session.ended_at),
      status: session.status
    }
  end

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  defp validation_error(conn, field, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{field => [message]}})
  end

  defp changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: changeset_errors(changeset)})
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
