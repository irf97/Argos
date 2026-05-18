defmodule ArgosWeb.Api.MCPController do
  use ArgosWeb, :controller

  alias Argos.MCP.Tools

  @server_version "0.1.0"
  @supported_protocol_versions ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

  def handle(conn, %{"method" => "initialize"} = request) do
    respond(conn, request, %{
      "protocolVersion" => protocol_version(request),
      "capabilities" => %{"tools" => %{"listChanged" => false}},
      "serverInfo" => %{"name" => "argos", "title" => "ARGOS", "version" => @server_version},
      "instructions" =>
        "ARGOS exposes local-first memory, canon, context pack, proposal, and crawl tools."
    })
  end

  def handle(conn, %{"method" => "notifications/initialized"}) do
    accepted(conn)
  end

  def handle(conn, %{"method" => "ping"} = request) do
    respond(conn, request, %{})
  end

  def handle(conn, %{"method" => "tools/list"} = request) do
    respond(conn, request, %{"tools" => Tools.list_tools()})
  end

  def handle(conn, %{"method" => "tools/call", "params" => params} = request) do
    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments") || %{}

    case Tools.call_tool(name, arguments) do
      {:ok, result} ->
        respond(conn, request, tool_result(result))

      {:error, reason} ->
        error(conn, request, -32602, inspect(reason))
    end
  end

  def handle(conn, %{"method" => method} = request) do
    if notification?(request) do
      accepted(conn)
    else
      error(conn, request, -32601, "method not found: #{method}")
    end
  end

  def handle(conn, request) do
    if notification_or_response?(request) do
      accepted(conn)
    else
      error(conn, request, -32600, "invalid request")
    end
  end

  def stream_unavailable(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_resp(:method_not_allowed, "")
  end

  defp tool_result(result) do
    %{
      "content" => [
        %{
          "type" => "text",
          "text" => Jason.encode!(result)
        }
      ],
      "structuredContent" => result,
      "isError" => false
    }
  end

  defp respond(conn, request, result) do
    json(conn, %{
      "jsonrpc" => "2.0",
      "id" => Map.get(request, "id"),
      "result" => result
    })
  end

  defp error(conn, request, code, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      "jsonrpc" => "2.0",
      "id" => Map.get(request, "id"),
      "error" => %{"code" => code, "message" => message}
    })
  end

  defp accepted(conn), do: send_resp(conn, :accepted, "")

  defp notification?(request), do: is_map(request) and not Map.has_key?(request, "id")

  defp notification_or_response?(request) do
    notification?(request) or
      (is_map(request) and (Map.has_key?(request, "result") or Map.has_key?(request, "error")))
  end

  defp protocol_version(request) do
    requested = get_in(request, ["params", "protocolVersion"])

    if requested in @supported_protocol_versions do
      requested
    else
      hd(@supported_protocol_versions)
    end
  end
end
