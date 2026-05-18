defmodule Argos.Context.Retrieval do
  @moduledoc """
  Postgres full-text retrieval for context pack doctrine chunks.
  """

  import Ecto.Query

  alias Argos.Context.DoctrineChunk
  alias Argos.Kernel.Hashing
  alias Argos.Repo

  @default_limit 5

  def create_chunk(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_known_keys()
      |> Map.put_new(:metadata, %{})
      |> put_content_hash()

    %DoctrineChunk{}
    |> DoctrineChunk.changeset(attrs)
    |> Repo.insert()
  end

  def search(opts) when is_list(opts), do: opts |> Map.new() |> search()

  def search(opts) when is_map(opts) do
    query = map_value(opts, "query")
    canon = map_value(opts, "canon")
    canon_version = map_value(opts, "canon_version")
    limit = map_value(opts, "limit") || @default_limit

    if blank?(query) do
      []
    else
      DoctrineChunk
      |> where([chunk], fragment("search_vector @@ websearch_to_tsquery('english', ?)", ^query))
      |> maybe_filter_canon(canon)
      |> maybe_filter_canon_version(canon_version)
      |> order_by(
        [chunk],
        desc: fragment("ts_rank_cd(search_vector, websearch_to_tsquery('english', ?))", ^query),
        asc: chunk.id
      )
      |> limit(^limit)
      |> select([chunk], %{
        chunk: chunk,
        rank: fragment("ts_rank_cd(search_vector, websearch_to_tsquery('english', ?))", ^query)
      })
      |> Repo.all()
    end
  end

  def result_json(%{chunk: chunk, rank: rank}) do
    %{
      "id" => chunk.id,
      "canon" => chunk.canon,
      "canon_version" => chunk.canon_version,
      "source" => chunk.source,
      "source_id" => chunk.source_id,
      "title" => chunk.title,
      "body" => chunk.body,
      "metadata" => chunk.metadata,
      "content_hash" => chunk.content_hash,
      "rank" => rank
    }
  end

  defp maybe_filter_canon(queryable, nil), do: queryable

  defp maybe_filter_canon(queryable, canon) do
    where(queryable, [chunk], chunk.canon == ^canon)
  end

  defp maybe_filter_canon_version(queryable, nil), do: queryable

  defp maybe_filter_canon_version(queryable, canon_version) do
    where(
      queryable,
      [chunk],
      chunk.canon_version == ^canon_version or is_nil(chunk.canon_version)
    )
  end

  defp put_content_hash(attrs) do
    Map.put_new(attrs, :content_hash, Hashing.sha256(Map.take(attrs, hash_fields())))
  end

  defp hash_fields do
    [:canon, :canon_version, :source, :source_id, :title, :body, :metadata]
  end

  defp normalize_known_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      pair -> pair
    end)
  end

  defp known_key("canon"), do: :canon
  defp known_key("canon_version"), do: :canon_version
  defp known_key("source"), do: :source
  defp known_key("source_id"), do: :source_id
  defp known_key("title"), do: :title
  defp known_key("body"), do: :body
  defp known_key("metadata"), do: :metadata
  defp known_key("content_hash"), do: :content_hash
  defp known_key(key), do: key

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp blank?(value), do: not is_binary(value) or String.trim(value) == ""
end
