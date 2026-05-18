defmodule ArgosWeb.Api.MCPControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Memory.Events

  test "POST /mcp initializes the JSON-RPC MCP surface", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => "2025-06-18"}
      })

    assert %{
             "jsonrpc" => "2.0",
             "id" => 1,
             "result" => %{
               "protocolVersion" => "2025-06-18",
               "capabilities" => %{"tools" => %{}},
               "serverInfo" => %{"name" => "argos"}
             }
           } = json_response(conn, 200)
  end

  test "POST /mcp accepts the initialized notification without a response body", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      })

    assert response(conn, 202) == ""
  end

  test "POST /mcp responds to ping", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "ping",
        "method" => "ping"
      })

    assert %{"id" => "ping", "result" => %{}} = json_response(conn, 200)
  end

  test "POST /mcp lists ARGOS tools", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "tools",
        "method" => "tools/list"
      })

    assert %{"result" => %{"tools" => tools}} = json_response(conn, 200)
    assert Enum.any?(tools, &(&1["name"] == "search"))
    assert Enum.any?(tools, &(&1["name"] == "fetch"))
    assert Enum.any?(tools, &(&1["name"] == "argos_capture"))
    assert Enum.any?(tools, &(&1["name"] == "argos_crawl"))
  end

  test "POST /mcp supports ChatGPT data-only search and fetch tools", %{conn: conn} do
    assert {:ok, event} =
             Events.append_event(%{
               kind: "manual_note",
               canon: "operator",
               source: "test",
               payload: %{"text" => "chatgpt roundtrip memory"},
               author: "operator"
             })

    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "search",
        "method" => "tools/call",
        "params" => %{
          "name" => "search",
          "arguments" => %{"query" => "chatgpt roundtrip"}
        }
      })

    assert %{
             "result" => %{
               "structuredContent" => %{
                 "results" => [%{"id" => result_id, "title" => title, "url" => url} | _]
               }
             }
           } = json_response(conn, 200)

    assert result_id == "event:#{event.id}"
    assert title =~ "ARGOS event manual_note"
    assert url =~ "/api/mcp-documents/events/#{event.id}"

    conn =
      build_conn()
      |> post(~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "fetch",
        "method" => "tools/call",
        "params" => %{
          "name" => "fetch",
          "arguments" => %{"id" => result_id}
        }
      })

    assert %{
             "result" => %{
               "structuredContent" => %{
                 "id" => ^result_id,
                 "text" => text,
                 "metadata" => %{"type" => "event"}
               }
             }
           } = json_response(conn, 200)

    assert text =~ "chatgpt roundtrip memory"
  end

  test "POST /mcp tools/call can append a capture event", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "capture",
        "method" => "tools/call",
        "params" => %{
          "name" => "argos_capture",
          "arguments" => %{
            "kind" => "manual_note",
            "canon_id" => "operator",
            "content" => "captured through mcp"
          }
        }
      })

    assert %{
             "result" => %{
               "isError" => false,
               "structuredContent" => %{
                 "event" => %{
                   "kind" => "manual_note",
                   "source" => "mcp",
                   "payload" => %{"content" => "captured through mcp"}
                 }
               }
             }
           } = json_response(conn, 200)
  end

  test "POST /mcp tools/call can compile a context pack", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "pack",
        "method" => "tools/call",
        "params" => %{
          "name" => "argos_pack",
          "arguments" => %{
            "task_descriptor" => "compile through mcp",
            "canon_id" => "operator"
          }
        }
      })

    assert %{
             "result" => %{
               "structuredContent" => %{
                 "context_pack" => %{
                   "task" => "compile through mcp",
                   "hash" => hash
                 }
               }
             }
           } = json_response(conn, 200)

    assert String.length(hash) == 64
  end

  test "POST /mcp reports unknown methods as JSON-RPC errors", %{conn: conn} do
    conn =
      post(conn, ~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => "bad",
        "method" => "not/a-method"
      })

    assert %{"error" => %{"code" => -32601}} = json_response(conn, 400)
  end

  test "GET /mcp reports that the server does not expose an SSE stream", %{conn: conn} do
    conn = get(conn, ~p"/mcp")

    assert response(conn, 405) == ""
    assert get_resp_header(conn, "allow") == ["POST"]
  end
end
