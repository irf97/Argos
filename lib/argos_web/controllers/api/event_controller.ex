defmodule ArgosWeb.Api.EventController do
  use ArgosWeb, :controller

  alias Argos.Memory.Events

  def index(conn, params) do
    opts =
      []
      |> maybe_put(:canon, Map.get(params, "canon"))
      |> maybe_put(:kind, Map.get(params, "kind"))
      |> maybe_put(:order, parse_order(Map.get(params, "order")))
      |> maybe_put(:limit, parse_limit(Map.get(params, "limit")))

    events = Events.list_events(opts)
    json(conn, %{events: Enum.map(events, &event_json/1)})
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

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_order("desc"), do: :desc
  defp parse_order(_order), do: nil

  defp parse_limit(nil), do: nil
  defp parse_limit(""), do: nil

  defp parse_limit(limit) do
    case Integer.parse(limit) do
      {integer, ""} -> integer
      _invalid -> nil
    end
  end
end
