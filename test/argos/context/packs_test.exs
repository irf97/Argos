defmodule Argos.Context.PacksTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
  alias Argos.Context.Packs
  alias Argos.Kernel.Hashing
  alias Argos.Memory.Canons
  alias Argos.Memory.Events

  describe "compile/2" do
    test "same fixed input produces the same hash and markdown" do
      attrs = %{canon: "operator", task: "compile memory pack", project: "argos"}
      opts = [compiled_at: fixed_time()]

      assert {:ok, first} = Packs.compile(attrs, opts)
      assert {:ok, second} = Packs.compile(attrs, opts)

      assert first.hash == second.hash
      assert first.markdown == second.markdown
      assert first.hash == Hashing.sha256(Map.delete(first.payload, "hash"))
    end

    test "includes canon version and recent event provenance" do
      {:ok, approval} = Canons.draft_canon("operator", %{state: %{"principle" => "local-first"}})
      {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

      {:ok, event} =
        Events.append_event(%{
          kind: "manual_note",
          canon: "operator",
          source: "test",
          payload: %{"text" => "important"},
          author: "operator",
          occurred_at: fixed_time()
        })

      assert {:ok, compiled} =
               Packs.compile(
                 %{canon: "operator", task: "use memory", project: "argos"},
                 compiled_at: fixed_time()
               )

      assert compiled.payload["canon_versions"] == %{"operator" => canon.version}
      assert compiled.payload["active_canon"]["hash"] == canon.hash
      assert event.hash in compiled.payload["provenance"]["source_event_hashes"]
      assert event.id in compiled.payload["provenance"]["source_event_ids"]
      assert compiled.markdown =~ "source_event_hashes"
    end
  end

  describe "create_pack/2" do
    test "persists a pack with hash, markdown, and provenance" do
      assert {:ok, pack} =
               Packs.create_pack(
                 %{canon: "operator", task: "persist pack", project: "argos"},
                 compiled_at: fixed_time()
               )

      assert String.length(pack.hash) == 64
      assert pack.markdown =~ "# Task"
      assert pack.payload["provenance"]["compiler_version"] == "context_pack_v1"
      assert Packs.get_pack_by_hash(pack.hash).id == pack.id
    end
  end

  defp fixed_time do
    DateTime.from_naive!(~N[2026-05-17 00:00:00.000000], "Etc/UTC")
  end
end
