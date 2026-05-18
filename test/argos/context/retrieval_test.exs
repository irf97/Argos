defmodule Argos.Context.RetrievalTest do
  use Argos.DataCase, async: true

  alias Argos.Context.Packs
  alias Argos.Context.Retrieval

  test "search ranks matching doctrine chunks" do
    {:ok, approval_chunk} =
      Retrieval.create_chunk(%{
        canon: "operator",
        canon_version: 1,
        source: "docs",
        source_id: "approval",
        title: "Approval Gates",
        body: "Canon commits require explicit operator approval before they are recorded.",
        metadata: %{"section" => "authority"}
      })

    {:ok, _other_chunk} =
      Retrieval.create_chunk(%{
        canon: "operator",
        canon_version: 1,
        source: "docs",
        source_id: "unrelated",
        title: "Runtime Notes",
        body: "Local logs and status pages are available for operators.",
        metadata: %{}
      })

    assert [%{chunk: chunk, rank: rank} | _] =
             Retrieval.search(query: "canon approval", canon: "operator", limit: 5)

    assert chunk.id == approval_chunk.id
    assert rank > 0
  end

  test "search filters by canon" do
    {:ok, operator_chunk} =
      Retrieval.create_chunk(%{
        canon: "operator",
        source: "docs",
        source_id: "operator-local",
        title: "Local First",
        body: "ARGOS is local first before cloud.",
        metadata: %{}
      })

    {:ok, _project_chunk} =
      Retrieval.create_chunk(%{
        canon: "project",
        source: "docs",
        source_id: "project-local",
        title: "Local First",
        body: "The project mentions local first for a different canon.",
        metadata: %{}
      })

    results = Retrieval.search(query: "local first", canon: "operator", limit: 5)

    assert Enum.map(results, & &1.chunk.id) == [operator_chunk.id]
  end

  test "context packs include retrieved doctrine provenance" do
    {:ok, chunk} =
      Retrieval.create_chunk(%{
        canon: "operator",
        source: "docs",
        source_id: "pack-provenance",
        title: "Context Provenance",
        body: "Context packs include provenance for retrieved doctrine chunks.",
        metadata: %{}
      })

    assert {:ok, compiled} =
             Packs.compile(
               %{canon: "operator", task: "include retrieved doctrine provenance"},
               compiled_at: fixed_time()
             )

    assert [retrieved] = compiled.payload["retrieved_doctrine_chunks"]
    assert retrieved["id"] == chunk.id
    assert retrieved["content_hash"] == chunk.content_hash
    assert compiled.payload["retrieval_policy"]["engine"] == "postgres_full_text"

    assert compiled.payload["provenance"]["retrieval_query"] ==
             "include retrieved doctrine provenance"

    assert chunk.id in compiled.payload["provenance"]["retrieved_doctrine_chunk_ids"]

    assert chunk.content_hash in compiled.payload["provenance"][
             "retrieved_doctrine_content_hashes"
           ]

    assert compiled.markdown =~ "Retrieved Doctrine"
  end

  defp fixed_time do
    DateTime.from_naive!(~N[2026-05-17 00:00:00.000000], "Etc/UTC")
  end
end
