defmodule ArgosWeb.Api.EventControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Memory.Events

  test "GET /api/events lists events with filters", %{conn: conn} do
    {:ok, event} =
      Events.append_event(%{
        kind: "manual_note",
        canon: "operator",
        source: "test",
        payload: %{"text" => "listed"},
        author: "operator"
      })

    conn = get(conn, ~p"/api/events?canon=operator&kind=manual_note&limit=1")

    assert %{"events" => [%{"id" => id, "hash" => hash, "payload" => %{"text" => "listed"}}]} =
             json_response(conn, 200)

    assert id == event.id
    assert hash == event.hash
  end
end
