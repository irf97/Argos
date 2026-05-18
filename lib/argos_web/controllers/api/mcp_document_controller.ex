defmodule ArgosWeb.Api.MCPDocumentController do
  use ArgosWeb, :controller

  alias Argos.Memory.Canons
  alias Argos.Memory.Events

  def show_event(conn, %{"id" => id}) do
    case Events.get_event(id) do
      nil ->
        send_resp(conn, :not_found, "")

      event ->
        json(conn, %{
          id: "event:#{event.id}",
          title: "ARGOS event #{event.kind} #{event.id}",
          text: Jason.encode!(event_json(event), pretty: true),
          metadata: %{
            source: "argos",
            type: "event",
            canon: event.canon,
            kind: event.kind,
            hash: event.hash
          }
        })
    end
  end

  def show_canon(conn, %{"id" => id}) do
    case Canons.get_canon_by_id(id) do
      nil ->
        send_resp(conn, :not_found, "")

      canon ->
        json(conn, %{
          id: "canon:#{canon.id}",
          title: "ARGOS canon #{canon.name} v#{canon.version}",
          text: Jason.encode!(canon_json(canon), pretty: true),
          metadata: %{
            source: "argos",
            type: "canon",
            canon: canon.name,
            version: canon.version,
            hash: canon.hash
          }
        })
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
end
