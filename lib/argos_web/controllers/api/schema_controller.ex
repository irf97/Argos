defmodule ArgosWeb.Api.SchemaController do
  use ArgosWeb, :controller

  alias Argos.Ingest.CrawlJobs
  alias Argos.MCP.Tools
  alias Argos.Memory.Event

  def show(conn, _params) do
    json(conn, %{
      schema_version: "argos_api_schema_v1",
      local_first: true,
      ai_execution: %{
        browser_runs_ai: false,
        supported_runners: ["codex_cli", "local_model_server", "mcp_client"],
        secrets_allowed_in_html: false
      },
      endpoints: endpoints(),
      event_kinds: Event.allowed_kinds(),
      shapes: %{
        crawl_job: crawl_job_shape(),
        crawl_output: CrawlJobs.output_schema(),
        context_pack_request: %{
          required: ["task"],
          optional: ["canon", "project", "operator_state_id", "retrieval_policy", "skill_refs"]
        }
      },
      mcp: %{
        endpoint: "/mcp",
        transport: "streamable_http_json_rpc",
        stdio_bridge: "scripts/argos-mcp-stdio.py",
        openai_compatible_tools: ["search", "fetch"],
        tools: Tools.list_tools()
      }
    })
  end

  defp endpoints do
    [
      endpoint("GET", "/api/health", "readiness and degradation summary"),
      endpoint("GET", "/api/schema", "machine-readable HTTP and MCP contract"),
      endpoint("GET", "/api/mcp-documents/events/:id", "read MCP citation document for event"),
      endpoint("GET", "/api/mcp-documents/canons/:id", "read MCP citation document for canon"),
      endpoint("POST", "/api/capture", "append an event"),
      endpoint("GET", "/api/events", "list events"),
      endpoint("GET", "/api/canon/:name", "read current canon"),
      endpoint("POST", "/api/canon/:name/draft", "create approval-gated canon draft"),
      endpoint("GET", "/api/approvals", "list approvals"),
      endpoint("POST", "/api/approvals/:id/approve", "approve queued item"),
      endpoint("POST", "/api/approvals/:id/reject", "reject queued item"),
      endpoint("POST", "/api/context-pack", "compile and persist context pack"),
      endpoint("GET", "/api/context-pack/:hash", "fetch context pack"),
      endpoint("POST", "/api/arms/session/start", "start Codex arm session"),
      endpoint("POST", "/api/arms/session/end", "end Codex arm session"),
      endpoint("POST", "/api/outcomes", "record arm outcome and scoring stub"),
      endpoint("GET", "/api/proposals", "list intelligence proposals"),
      endpoint("POST", "/api/proposals/detect", "run proposal detectors"),
      endpoint("GET", "/api/autonomous-mutations", "list autonomous mutation audit rows"),
      endpoint(
        "POST",
        "/api/autonomous-mutations/:proposal_id/rollback",
        "rollback within window"
      ),
      endpoint("POST", "/api/crawl", "create local crawl prompt packet"),
      endpoint("POST", "/api/crawl-and-ingest", "persist local AI output and normalized records"),
      endpoint("GET", "/api/crawl-jobs", "list local crawl jobs"),
      endpoint("GET", "/api/crawl-jobs/:id", "fetch local crawl job"),
      endpoint("GET", "/mcp", "MCP stream endpoint unavailable; use POST or stdio bridge"),
      endpoint("POST", "/mcp", "MCP-compatible JSON-RPC tool endpoint")
    ]
  end

  defp endpoint(method, path, purpose), do: %{method: method, path: path, purpose: purpose}

  defp crawl_job_shape do
    %{
      required: ["id", "kind", "status", "seek", "prompt", "raw_input", "raw_output"],
      optional: ["normalized_records", "event_id", "error", "completed_at"],
      statuses: ["queued", "completed", "failed"],
      kinds: ["crawl", "crawl_and_ingest"]
    }
  end
end
