defmodule ArgosWeb.Api.SchemaControllerTest do
  use ArgosWeb.ConnCase, async: true

  test "GET /api/schema returns the local-first HTTP and MCP contract", %{conn: conn} do
    conn = get(conn, ~p"/api/schema")

    assert %{
             "local_first" => true,
             "ai_execution" => %{"browser_runs_ai" => false},
             "endpoints" => endpoints,
             "event_kinds" => event_kinds,
             "mcp" => %{
               "endpoint" => "/mcp",
               "stdio_bridge" => "scripts/argos-mcp-stdio.py",
               "tools" => tools
             },
             "shapes" => %{"crawl_output" => %{"required" => ["records"]}}
           } = json_response(conn, 200)

    assert Enum.any?(endpoints, &(&1["path"] == "/api/crawl"))
    assert Enum.any?(endpoints, &(&1["path"] == "/api/crawl-and-ingest"))
    assert Enum.any?(tools, &(&1["name"] == "argos_crawl_and_ingest"))
    assert "crawl_ingested" in event_kinds
  end
end
