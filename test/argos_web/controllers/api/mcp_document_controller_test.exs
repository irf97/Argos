defmodule ArgosWeb.Api.MCPDocumentControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Memory.Events

  test "GET /api/mcp-documents/events/:id returns a citation document", %{conn: conn} do
    assert {:ok, event} =
             Events.append_event(%{
               kind: "manual_note",
               canon: "operator",
               source: "test",
               payload: %{"text" => "citation event"},
               author: "operator"
             })

    conn = get(conn, ~p"/api/mcp-documents/events/#{event.id}")

    assert %{
             "id" => "event:" <> _,
             "title" => "ARGOS event manual_note " <> _,
             "text" => text,
             "metadata" => %{"source" => "argos", "type" => "event"}
           } = json_response(conn, 200)

    assert text =~ "citation event"
  end
end
