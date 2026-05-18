defmodule Argos.Intelligence.ProposalsTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.Canons

  test "contradiction detector creates a proposal with evidence and approval" do
    assert [{:ok, proposal}] =
             Proposals.detect(%{
               "canon" => "operator",
               "detectors" => ["contradiction"],
               "claims" => [
                 %{"topic" => "publish_policy", "value" => "approval_required", "source" => "a"},
                 %{"topic" => "publish_policy", "value" => "auto_publish", "source" => "b"}
               ]
             })

    assert proposal.type == "contradiction"
    assert proposal.evidence["topic"] == "publish_policy"
    assert proposal.proposed_action["autonomous_action"] == false
    assert proposal.approval_id
    assert Approvals.get_approval!(proposal.approval_id).status == "pending"
  end

  test "gap detector creates a proposal with missing-topic evidence" do
    assert [{:ok, proposal}] =
             Proposals.detect(%{
               "canon" => "operator",
               "detectors" => ["gap"],
               "required_topics" => ["security", "provenance"],
               "present_topics" => ["security"]
             })

    assert proposal.type == "gap"
    assert proposal.evidence["missing_topics"] == ["provenance"]
    assert proposal.risk_level == "low"
  end

  test "approving a proposal does not mutate canon automatically" do
    {:ok, canon_approval} =
      Canons.draft_canon("operator", %{state: %{"principle" => "approval required"}})

    {:ok, _approval, canon} = Approvals.approve(canon_approval.id, %{decided_by: "operator"})

    [{:ok, proposal}] =
      Proposals.detect(%{
        "canon" => "operator",
        "detectors" => ["gap"],
        "required_topics" => ["new-topic"],
        "present_topics" => []
      })

    assert {:ok, decided_approval, nil} =
             Approvals.approve(proposal.approval_id, %{decided_by: "operator"})

    assert decided_approval.action == "proposal_review"
    assert Canons.get_canon("operator").hash == canon.hash
    assert Canons.get_canon("operator").version == 1
  end

  test "stats returns pending proposals" do
    [{:ok, proposal}] =
      Proposals.detect(%{
        "canon" => "operator",
        "detectors" => ["gap"],
        "required_topics" => ["provenance"],
        "present_topics" => []
      })

    stats = Proposals.stats()

    assert stats.pending_proposal_count == 1
    assert hd(stats.pending_proposals).id == proposal.id
  end
end
