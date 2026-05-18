defmodule Argos.MCP.Tools do
  @moduledoc """
  Agent-facing tool surface for local ARGOS capabilities.
  """

  alias Argos.Context.Packs
  alias Argos.Ingest.CrawlJobs
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.Canons
  alias Argos.Memory.Events

  def list_tools do
    [
      tool(
        "search",
        "Search ARGOS memory for ChatGPT data-only, company knowledge, and deep research MCP clients. Use this when the user asks to find remembered events, canons, decisions, or prior work.",
        %{
          "type" => "object",
          "required" => ["query"],
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "Search terms to match against ARGOS events and canons."
            }
          }
        },
        %{
          "type" => "object",
          "required" => ["results"],
          "properties" => %{
            "results" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["id", "title", "url"],
                "properties" => %{
                  "id" => %{"type" => "string"},
                  "title" => %{"type" => "string"},
                  "url" => %{"type" => "string"}
                }
              }
            }
          }
        }
      ),
      tool(
        "fetch",
        "Fetch one ARGOS memory document returned by search. Use this after search to read full event or canon content.",
        %{
          "type" => "object",
          "required" => ["id"],
          "properties" => %{
            "id" => %{
              "type" => "string",
              "description" => "A search result id such as event:<uuid> or canon:<uuid>."
            }
          }
        },
        %{
          "type" => "object",
          "required" => ["id", "title", "text", "url"],
          "properties" => %{
            "id" => %{"type" => "string"},
            "title" => %{"type" => "string"},
            "text" => %{"type" => "string"},
            "url" => %{"type" => "string"},
            "metadata" => %{"type" => "object"}
          }
        }
      ),
      tool("argos_search", "Search events, canons, or skills.", %{
        "type" => "object",
        "required" => ["query"],
        "properties" => %{
          "query" => %{"type" => "string"},
          "scope" => %{"type" => "string", "enum" => ["events", "canons", "skills"]},
          "canon_id" => %{"type" => "string"},
          "limit" => %{"type" => "integer"}
        }
      }),
      tool("argos_pack", "Compile and persist a context pack.", %{
        "type" => "object",
        "required" => ["task_descriptor"],
        "properties" => %{
          "task_descriptor" => %{"type" => "string"},
          "canon_id" => %{"type" => "string"}
        }
      }),
      tool("argos_capture", "Append a low-stakes event to the ARGOS memory log.", %{
        "type" => "object",
        "required" => ["kind", "content"],
        "properties" => %{
          "kind" => %{"type" => "string"},
          "content" => %{},
          "metadata" => %{"type" => "object"},
          "canon_id" => %{"type" => "string"},
          "pack_id" => %{"type" => "string"}
        }
      }),
      tool("argos_propose", "Submit a proposal to the operator approval queue.", %{
        "type" => "object",
        "required" => ["kind", "body"],
        "properties" => %{
          "kind" => %{
            "type" => "string",
            "enum" => ["canon_update", "policy_update", "experiment", "gap_fill"]
          },
          "body" => %{"type" => "object"}
        }
      }),
      tool("argos_state", "Read the current operator-state placeholder and recent events.", %{
        "type" => "object",
        "properties" => %{"limit" => %{"type" => "integer"}}
      }),
      tool("argos_crawl", "Create a local crawl prompt packet without running remote AI.", %{
        "type" => "object",
        "properties" => %{
          "seek" => %{"type" => "object"},
          "prompt" => %{"type" => "string"}
        }
      }),
      tool("argos_crawl_and_ingest", "Persist local AI crawl output as normalized records.", %{
        "type" => "object",
        "required" => ["records"],
        "properties" => %{
          "seek" => %{"type" => "object"},
          "records" => %{"type" => "array"},
          "raw_output" => %{"type" => "object"},
          "canon" => %{"type" => "string"}
        }
      })
    ]
  end

  def call_tool("search", args) when is_map(args) do
    query = map_value(args, "query") || ""

    results =
      search_events(query, nil, 10)
      |> Enum.map(&event_search_result/1)
      |> Kernel.++(
        search_canons(query, 10)
        |> Enum.map(&canon_search_result/1)
      )
      |> Enum.take(10)

    {:ok, %{"results" => results}}
  end

  def call_tool("fetch", args) when is_map(args) do
    id = map_value(args, "id")

    case fetch_document(id) do
      {:ok, document} -> {:ok, document}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_tool("argos_search", args) when is_map(args) do
    scope = map_value(args, "scope") || "events"
    query = map_value(args, "query") || ""
    limit = parse_limit(map_value(args, "limit")) || 10

    results =
      case scope do
        "canons" -> search_canons(query, limit)
        "skills" -> []
        _events -> search_events(query, map_value(args, "canon_id"), limit)
      end

    {:ok, %{"scope" => scope, "query" => query, "results" => results}}
  end

  def call_tool("argos_pack", args) when is_map(args) do
    attrs = %{
      "task" => map_value(args, "task_descriptor") || map_value(args, "task"),
      "canon" => map_value(args, "canon_id") || map_value(args, "canon") || "operator"
    }

    case Packs.create_pack(attrs) do
      {:ok, pack} -> {:ok, %{"context_pack" => context_pack_json(pack)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_tool("argos_capture", args) when is_map(args) do
    payload =
      map_value(args, "payload") ||
        %{
          "content" => map_value(args, "content"),
          "metadata" => map_value(args, "metadata") || %{},
          "pack_id" => map_value(args, "pack_id")
        }

    attrs = %{
      kind: map_value(args, "kind"),
      canon: map_value(args, "canon_id") || map_value(args, "canon") || "operator",
      source: "mcp",
      payload: payload,
      author: map_value(args, "author") || "codex"
    }

    case Events.append_event(attrs) do
      {:ok, event} -> {:ok, %{"event" => event_json(event)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_tool("argos_propose", args) when is_map(args) do
    body = map_value(args, "body") || %{}
    kind = map_value(args, "kind") || map_value(body, "kind") || "canon_update"

    proposal_attrs = %{
      "type" => kind,
      "canon" => map_value(body, "canon") || map_value(args, "canon_id") || "operator",
      "canon_version" => map_value(body, "canon_version"),
      "title" => map_value(body, "title") || "#{kind} proposal",
      "summary" => map_value(body, "summary") || "MCP-submitted proposal.",
      "evidence" => map_value(body, "evidence") || %{"body" => body},
      "proposed_action" =>
        map_value(body, "proposed_action") || %{"kind" => kind, "body" => body},
      "risk_level" => map_value(body, "risk_level") || "medium",
      "detector_version" => "mcp_v1"
    }

    case Proposals.create_proposal(proposal_attrs) do
      {:ok, proposal} -> {:ok, %{"proposal" => proposal_json(proposal)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_tool("argos_state", args) when is_map(args) do
    limit = parse_limit(map_value(args, "limit")) || 5
    recent_events = Events.list_events(order: :desc, limit: limit) |> Enum.map(&event_json/1)

    {:ok,
     %{
       "event_memory" => %{
         "implemented" => true,
         "recent_event_count" => length(recent_events),
         "write_tool" => "argos_capture",
         "search_tool" => "argos_search"
       },
       "operator_state" => nil,
       "operator_state_implemented" => false,
       "note" => "operator_states capture is not implemented yet; event memory is implemented.",
       "recent_events" => recent_events
     }}
  end

  def call_tool("argos_crawl", args) when is_map(args) do
    case CrawlJobs.create_crawl(args) do
      {:ok, job} -> {:ok, %{"crawl_job" => crawl_job_json(job)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_tool("argos_crawl_and_ingest", args) when is_map(args) do
    case CrawlJobs.crawl_and_ingest(args) do
      {:ok, %{job: job, event: event}} ->
        {:ok, %{"crawl_job" => crawl_job_json(job), "event" => event_json(event)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def call_tool(name, _args), do: {:error, {:unknown_tool, name}}

  defp fetch_document("event:" <> event_id), do: fetch_event_document(event_id)
  defp fetch_document("canon:" <> canon_id), do: fetch_canon_document(canon_id)

  defp fetch_document(id) when is_binary(id) do
    cond do
      event = Events.get_event(id) -> {:ok, event_document(event)}
      canon = Canons.get_canon_by_id(id) -> {:ok, canon_document(canon)}
      true -> {:error, :document_not_found}
    end
  end

  defp fetch_document(_id), do: {:error, :id_required}

  defp fetch_event_document(event_id) do
    case Events.get_event(event_id) do
      nil -> {:error, :document_not_found}
      event -> {:ok, event_document(event)}
    end
  end

  defp fetch_canon_document(canon_id) do
    case Canons.get_canon_by_id(canon_id) do
      nil -> {:error, :document_not_found}
      canon -> {:ok, canon_document(canon)}
    end
  end

  defp search_events(query, canon, limit) do
    [order: :desc, limit: 100]
    |> maybe_put(:canon, canon)
    |> Events.list_events()
    |> Enum.filter(&matches_query?(&1, query))
    |> Enum.take(limit)
    |> Enum.map(&event_json/1)
  end

  defp search_canons(query, limit) do
    Canons.list_canons()
    |> Enum.filter(&matches_query?(&1, query))
    |> Enum.take(limit)
    |> Enum.map(&canon_json/1)
  end

  defp matches_query?(_record, ""), do: true

  defp matches_query?(record, query) do
    haystack =
      record
      |> inspect(limit: :infinity)
      |> String.downcase()

    String.contains?(haystack, String.downcase(query))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_limit(limit) when is_integer(limit) and limit > 0, do: limit

  defp parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {integer, ""} when integer > 0 -> integer
      _invalid -> nil
    end
  end

  defp parse_limit(_limit), do: nil

  defp tool(name, description, input_schema) do
    %{
      "name" => name,
      "description" => description,
      "inputSchema" => input_schema
    }
  end

  defp tool(name, description, input_schema, output_schema) do
    name
    |> tool(description, input_schema)
    |> Map.put("outputSchema", output_schema)
  end

  defp event_search_result(event) do
    id = record_value(event, "id")
    kind = record_value(event, "kind")

    %{
      "id" => "event:#{id}",
      "title" => "ARGOS event #{kind} #{id}",
      "url" => document_url("events", id)
    }
  end

  defp canon_search_result(canon) do
    id = record_value(canon, "id")
    name = record_value(canon, "name")
    version = record_value(canon, "version")

    %{
      "id" => "canon:#{id}",
      "title" => "ARGOS canon #{name} v#{version}",
      "url" => document_url("canons", id)
    }
  end

  defp event_document(event) do
    json = Jason.encode!(event_json(event), pretty: true)

    %{
      "id" => "event:#{event.id}",
      "title" => "ARGOS event #{event.kind} #{event.id}",
      "text" => json,
      "url" => document_url("events", event.id),
      "metadata" => %{
        "source" => "argos",
        "type" => "event",
        "canon" => event.canon,
        "kind" => event.kind,
        "hash" => event.hash
      }
    }
  end

  defp canon_document(canon) do
    json = Jason.encode!(canon_json(canon), pretty: true)

    %{
      "id" => "canon:#{canon.id}",
      "title" => "ARGOS canon #{canon.name} v#{canon.version}",
      "text" => json,
      "url" => document_url("canons", canon.id),
      "metadata" => %{
        "source" => "argos",
        "type" => "canon",
        "canon" => canon.name,
        "version" => canon.version,
        "hash" => canon.hash
      }
    }
  end

  defp document_url(type, id) do
    base =
      System.get_env("ARGOS_PUBLIC_URL") ||
        System.get_env("ARGOS_URL") ||
        "http://localhost:#{System.get_env("PORT", "4000")}"

    "#{String.trim_trailing(base, "/")}/api/mcp-documents/#{type}/#{id}"
  end

  defp event_json(event) do
    %{
      "id" => event.id,
      "kind" => event.kind,
      "canon" => event.canon,
      "source" => event.source,
      "payload" => event.payload,
      "prev_hash" => event.prev_hash,
      "hash" => event.hash,
      "author" => event.author,
      "occurred_at" => DateTime.to_iso8601(event.occurred_at),
      "inserted_at" => DateTime.to_iso8601(event.inserted_at)
    }
  end

  defp canon_json(canon) do
    %{
      "id" => canon.id,
      "name" => canon.name,
      "version" => canon.version,
      "state" => canon.state,
      "autonomy_policy" => canon.autonomy_policy,
      "ancestor_hash" => canon.ancestor_hash,
      "hash" => canon.hash,
      "status" => canon.status,
      "approved_by" => canon.approved_by,
      "approved_at" => DateTime.to_iso8601(canon.approved_at)
    }
  end

  defp context_pack_json(pack) do
    %{
      "id" => pack.id,
      "hash" => pack.hash,
      "task" => pack.task,
      "canon" => pack.canon,
      "canon_versions" => pack.canon_versions,
      "operator_state_id" => pack.operator_state_id,
      "retrieval_policy" => pack.retrieval_policy,
      "skill_refs" => pack.skill_refs,
      "payload" => pack.payload,
      "markdown" => pack.markdown,
      "compiled_at" => DateTime.to_iso8601(pack.compiled_at)
    }
  end

  defp proposal_json(proposal) do
    %{
      "id" => proposal.id,
      "type" => proposal.type,
      "canon" => proposal.canon,
      "canon_version" => proposal.canon_version,
      "status" => proposal.status,
      "title" => proposal.title,
      "summary" => proposal.summary,
      "evidence" => proposal.evidence,
      "proposed_action" => proposal.proposed_action,
      "risk_level" => proposal.risk_level,
      "approval_id" => proposal.approval_id,
      "detector_version" => proposal.detector_version,
      "dedupe_hash" => proposal.dedupe_hash
    }
  end

  def crawl_job_json(job) do
    %{
      "id" => job.id,
      "kind" => job.kind,
      "status" => job.status,
      "seek" => job.seek,
      "prompt" => job.prompt,
      "raw_input" => job.raw_input,
      "raw_output" => job.raw_output,
      "normalized_records" => job.normalized_records,
      "event_id" => job.event_id,
      "error" => job.error,
      "requested_at" => DateTime.to_iso8601(job.requested_at),
      "completed_at" => if(job.completed_at, do: DateTime.to_iso8601(job.completed_at))
    }
  end

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp record_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
