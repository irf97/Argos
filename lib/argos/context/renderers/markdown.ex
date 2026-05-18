defmodule Argos.Context.Renderers.Markdown do
  @moduledoc """
  Markdown renderer for ARGOS context packs.
  """

  def render(payload) when is_map(payload) do
    provenance = Map.get(payload, "provenance", %{})
    active_canon = Map.get(payload, "active_canon")
    events = Map.get(payload, "recent_events", [])
    chunks = Map.get(payload, "retrieved_doctrine_chunks", [])

    """
    ---
    argos_context_pack: v1
    hash: #{Map.get(payload, "hash", "pending")}
    canon: #{Map.get(payload, "canon")}
    task: #{Map.get(payload, "task")}
    compiled_at: #{Map.get(payload, "compiled_at")}
    retrieval_policy: #{Jason.encode!(Map.get(payload, "retrieval_policy", %{}))}
    ---

    # Task

    #{Map.get(payload, "task")}

    # Active Canon

    #{render_canon(active_canon)}

    # Relevant Events

    #{render_events(events)}

    # Retrieved Doctrine

    #{render_chunks(chunks)}

    # Provenance

    - compiler_version: #{Map.get(provenance, "compiler_version")}
    - source_event_hashes: #{Enum.join(Map.get(provenance, "source_event_hashes", []), ", ")}
    - source_event_ids: #{Enum.join(Map.get(provenance, "source_event_ids", []), ", ")}
    - retrieval_query: #{Map.get(provenance, "retrieval_query")}
    - retrieved_doctrine_chunk_ids: #{Enum.join(Map.get(provenance, "retrieved_doctrine_chunk_ids", []), ", ")}
    - retrieved_doctrine_content_hashes: #{Enum.join(Map.get(provenance, "retrieved_doctrine_content_hashes", []), ", ")}

    # Constraints

    - immutable canon
    - append-only events
    - approval required for canon commit
    - tests required
    """
    |> String.trim()
  end

  defp render_canon(nil), do: "No approved canon found."

  defp render_canon(canon) do
    """
    - name: #{Map.get(canon, "name")}
    - version: #{Map.get(canon, "version")}
    - hash: #{Map.get(canon, "hash")}
    - state: #{Jason.encode!(Map.get(canon, "state", %{}))}
    """
    |> String.trim()
  end

  defp render_events([]), do: "No relevant events found."

  defp render_events(events) do
    Enum.map_join(events, "\n", fn event ->
      "- #{Map.get(event, "kind")} #{Map.get(event, "hash")}: #{Jason.encode!(Map.get(event, "payload", %{}))}"
    end)
  end

  defp render_chunks([]), do: "No doctrine chunks retrieved."

  defp render_chunks(chunks) do
    Enum.map_join(chunks, "\n", fn chunk ->
      "- #{Map.get(chunk, "title")} #{Map.get(chunk, "content_hash")}: #{Map.get(chunk, "body")}"
    end)
  end
end
