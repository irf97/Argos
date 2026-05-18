defmodule Argos.Memory.CanonsTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
  alias Argos.Memory.Canons
  alias Argos.Memory.Canon
  alias Argos.Memory.Events

  describe "draft_canon/2" do
    test "creates an approval and records a draft event without committing a canon" do
      assert {:ok, approval} =
               Canons.draft_canon("operator", %{
                 state: %{"principle" => "local-first"},
                 author: "operator",
                 reason: "initial canon"
               })

      assert approval.status == "pending"
      assert approval.action == "canon_commit"
      assert approval.proposal["version"] == 1
      assert Canons.get_canon("operator") == nil

      kinds = Events.list_events(canon: "operator") |> Enum.map(& &1.kind)
      assert "approval_created" in kinds
      assert "canon_draft" in kinds
    end

    test "rejects non-map state" do
      assert {:error, :invalid_state} =
               Canons.draft_canon("operator", %{state: "raw", author: "operator"})
    end
  end

  describe "approval-gated commits" do
    test "approval commits an immutable canon version and emits canon_commit" do
      {:ok, approval} =
        Canons.draft_canon("operator", %{
          state: %{"principle" => "local-first"},
          author: "operator"
        })

      assert {:ok, decided_approval, canon} =
               Approvals.approve(approval.id, %{decided_by: "operator"})

      assert decided_approval.status == "approved"
      assert canon.name == "operator"
      assert canon.version == 1
      assert canon.state == %{"principle" => "local-first"}
      assert canon.approved_by == "operator"
      assert Canons.get_canon("operator").id == canon.id

      assert "canon_commit" in (Events.list_events(canon: "operator") |> Enum.map(& &1.kind))
    end

    test "rejection does not commit a canon" do
      {:ok, approval} =
        Canons.draft_canon("operator", %{state: %{"principle" => "operator approval"}})

      assert {:ok, decided_approval, nil} =
               Approvals.reject(approval.id, %{decided_by: "operator"})

      assert decided_approval.status == "rejected"
      assert Canons.get_canon("operator") == nil
    end

    test "versions increment and link ancestor hashes" do
      {:ok, first_approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

      {:ok, _approval, first_canon} =
        Approvals.approve(first_approval.id, %{decided_by: "operator"})

      {:ok, second_approval} = Canons.draft_canon("operator", %{state: %{"version" => 2}})

      {:ok, _approval, second_canon} =
        Approvals.approve(second_approval.id, %{decided_by: "operator"})

      assert second_canon.version == 2
      assert second_canon.ancestor_hash == first_canon.hash
    end

    test "pending approvals cannot be committed directly" do
      {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

      assert {:error, :approval_not_committable} = Canons.commit_approved_canon(approval)
    end

    test "canon rows cannot be mutated" do
      {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})
      {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

      assert_raise Postgrex.Error, ~r/canon versions are immutable/, fn ->
        canon
        |> change(state: %{"version" => 2})
        |> Repo.update!()
      end

      assert Repo.get!(Canon, canon.id).state == %{"version" => 1}
    end
  end
end
