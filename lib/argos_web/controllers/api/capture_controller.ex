defmodule ArgosWeb.Api.CaptureController do
  use ArgosWeb, :controller

  alias Argos.Memory.Events

  def create(conn, params) do
    case Events.append_event(params) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{event: event_json(event)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  defp event_json(event) do
    %{
      id: event.id,
      kind: event.kind,
      canon: event.canon,
      source: event.source,
      payload: event.payload,
      prev_hash: event.prev_hash,
      hash: event.hash,
      author: event.author,
      occurred_at: DateTime.to_iso8601(event.occurred_at),
      inserted_at: DateTime.to_iso8601(event.inserted_at)
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
