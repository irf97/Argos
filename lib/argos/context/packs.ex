defmodule Argos.Context.Packs do
  @moduledoc """
  Context pack compiler and persistence.
  """

  alias Argos.Context.ContextPack
  alias Argos.Context.Renderers.Markdown
  alias Argos.Context.Retrieval
  alias Argos.Kernel.Hashing
  alias Argos.Memory.Canons
  alias Argos.Memory.Events
  alias Argos.Repo

  @compiler_version "context_pack_v1"
  @default_retrieval_policy %{
    "engine" => "postgres_full_text",
    "version" => "v1",
    "limit" => 5,
    "query_source" => "task",
    "embeddings" => false
  }

  def compile(attrs, opts \\ []) when is_map(attrs) do
    compiled_at = Keyword.get(opts, :compiled_at, DateTime.utc_now())

    with {:ok, payload_without_hash} <- compile_payload(attrs, compiled_at) do
      hash = Hashing.sha256(payload_without_hash)
      payload = Map.put(payload_without_hash, "hash", hash)
      markdown = Markdown.render(payload)

      {:ok,
       %{
         hash: hash,
         payload: payload,
         markdown: markdown,
         compiled_at: compiled_at
       }}
    end
  end

  def create_pack(attrs, opts \\ []) when is_map(attrs) do
    with {:ok, compiled} <- compile(attrs, opts) do
      attrs =
        compiled.payload
        |> Map.take([
          "task",
          "canon",
          "canon_versions",
          "operator_state_id",
          "retrieval_policy",
          "skill_refs",
          "compiled_at"
        ])
        |> Map.merge(%{
          "hash" => compiled.hash,
          "payload" => compiled.payload,
          "markdown" => compiled.markdown
        })

      %ContextPack{}
      |> ContextPack.changeset(attrs)
      |> Repo.insert()
    end
  end

  def get_pack_by_hash(hash) when is_binary(hash) do
    Repo.get_by(ContextPack, hash: hash)
  end

  def get_pack!(id), do: Repo.get!(ContextPack, id)

  def render_markdown(%ContextPack{} = pack), do: pack.markdown
  def render_markdown(payload) when is_map(payload), do: Markdown.render(payload)

  def render_json(%ContextPack{} = pack), do: pack.payload
  def render_json(payload) when is_map(payload), do: Argos.Context.Renderers.JSON.render(payload)

  defp compile_payload(attrs, compiled_at) do
    task = map_value(attrs, "task")
    canon_name = map_value(attrs, "canon") || "operator"

    cond do
      not is_binary(task) or task == "" ->
        {:error, :task_required}

      not is_binary(canon_name) or canon_name == "" ->
        {:error, :canon_required}

      true ->
        active_canon = Canons.get_canon(canon_name)
        recent_events = Events.list_events(canon: canon_name, order: :desc, limit: 10)
        retrieval_policy = map_value(attrs, "retrieval_policy") || @default_retrieval_policy
        retrieval_query = task

        retrieved_chunks =
          Retrieval.search(
            query: retrieval_query,
            canon: canon_name,
            canon_version: if(active_canon, do: active_canon.version),
            limit: Map.get(retrieval_policy, "limit", 5)
          )
          |> Enum.map(&Retrieval.result_json/1)

        canon_versions =
          if active_canon do
            %{active_canon.name => active_canon.version}
          else
            %{}
          end

        payload = %{
          "task" => task,
          "project" => map_value(attrs, "project"),
          "canon" => canon_name,
          "canon_versions" => canon_versions,
          "operator_state_id" => map_value(attrs, "operator_state_id"),
          "retrieval_policy" => retrieval_policy,
          "skill_refs" => map_value(attrs, "skill_refs") || %{},
          "compiled_at" => DateTime.to_iso8601(compiled_at),
          "compiler_version" => @compiler_version,
          "active_canon" => canon_json(active_canon),
          "recent_events" => Enum.map(recent_events, &event_json/1),
          "retrieved_doctrine_chunks" => retrieved_chunks,
          "decisions" =>
            recent_events
            |> Enum.filter(&(&1.kind == "decision_recorded"))
            |> Enum.map(&event_json/1),
          "provenance" => %{
            "compiler_version" => @compiler_version,
            "source_event_hashes" => Enum.map(recent_events, & &1.hash),
            "source_event_ids" => Enum.map(recent_events, & &1.id),
            "retrieval_policy" => retrieval_policy,
            "retrieval_query" => retrieval_query,
            "retrieved_doctrine_chunk_ids" => Enum.map(retrieved_chunks, & &1["id"]),
            "retrieved_doctrine_content_hashes" =>
              Enum.map(retrieved_chunks, & &1["content_hash"]),
            "missing_dependencies" => []
          }
        }

        {:ok, payload}
    end
  end

  defp canon_json(nil), do: nil

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
      "approved_at" => DateTime.to_iso8601(canon.approved_at)
    }
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
      "occurred_at" => DateTime.to_iso8601(event.occurred_at)
    }
  end

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
