defmodule Argos.Memory.AutonomousMutationsTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.AutonomousMutations
  alias Argos.Memory.Canons

  test "default canons still require approval for canon-changing proposals" do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"principle" => "approval-first"}})
    {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

    {:ok, proposal} = Proposals.create_proposal(gap_fill_attrs())

    assert proposal.status == "pending"
    assert proposal.approval_id
    assert Canons.get_canon("operator").hash == canon.hash
  end

  test "allowed bounded proposal auto-applies and writes audit row" do
    {:ok, _canon} = create_autonomous_canon()

    {:ok, proposal} = Proposals.create_proposal(gap_fill_attrs())

    latest = Canons.get_canon("operator")
    mutation = AutonomousMutations.get_by_proposal_id(proposal.id)

    assert proposal.status == "auto_applied"
    assert proposal.approval_id == nil
    assert latest.version == 2
    assert latest.state["missing_topic"] == "covered"
    assert mutation.prior_canon_version == 1
    assert mutation.new_canon_version == 2
    assert mutation.rollback_expires_at
    assert mutation.autonomy_policy_snapshot["mode"] == "auto_apply_bounded"
  end

  test "protected autonomy-policy changes still require approval" do
    {:ok, canon} = create_autonomous_canon()

    attrs =
      gap_fill_attrs(%{
        proposed_action: %{
          "kind" => "gap_fill",
          "canon_state_patch" => %{
            "autonomy_policy" => %{"mode" => "auto_apply_open"}
          },
          "confidence" => "evidenced-in-chat",
          "invocation_evidence" => 3
        }
      })

    {:ok, proposal} = Proposals.create_proposal(attrs)

    assert proposal.status == "pending"
    assert proposal.approval_id
    assert Canons.get_canon("operator").hash == canon.hash
  end

  test "daily cap queues out-of-bounds proposal for approval" do
    {:ok, _canon} = create_autonomous_canon()

    {:ok, first_proposal} = Proposals.create_proposal(gap_fill_attrs(%{title: "First gap fill"}))

    {:ok, second_proposal} =
      Proposals.create_proposal(gap_fill_attrs(%{title: "Second gap fill"}))

    assert first_proposal.status == "auto_applied"
    assert second_proposal.status == "pending"
    assert second_proposal.approval_id
  end

  test "rollback within 24 hours restores prior state through a new canon version" do
    {:ok, _canon} = create_autonomous_canon()
    {:ok, proposal} = Proposals.create_proposal(gap_fill_attrs())
    assert Canons.get_canon("operator").state["missing_topic"] == "covered"

    assert {:ok, mutation, rollback_canon, rolled_back_proposal} =
             AutonomousMutations.rollback(proposal.id, %{
               "operator" => "operator",
               "reason" => "bad automatic read"
             })

    assert mutation.rollback_reason == "bad automatic read"
    assert rolled_back_proposal.status == "rolled_back"
    assert rollback_canon.version == 3
    assert rollback_canon.state == %{"principle" => "bounded autonomy"}
    assert Canons.get_canon("operator").id == rollback_canon.id
  end

  defp create_autonomous_canon do
    {:ok, approval} =
      Canons.draft_canon("operator", %{
        state: %{"principle" => "bounded autonomy"},
        autonomy_policy: %{
          "mode" => "auto_apply_bounded",
          "allowed_proposal_kinds" => ["gap_fill"],
          "severity_ceiling" => "low",
          "daily_cap" => 1,
          "min_invocation_evidence" => 2,
          "min_confidence" => "evidenced-in-chat"
        }
      })

    {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})
    {:ok, canon}
  end

  defp gap_fill_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        type: "gap_fill",
        canon: "operator",
        title: "Fill missing topic",
        summary: "A bounded gap fill proposal.",
        evidence: %{"missing_topics" => ["missing_topic"]},
        proposed_action: %{
          "kind" => "gap_fill",
          "canon_state_patch" => %{"missing_topic" => "covered"},
          "confidence" => "evidenced-in-chat",
          "invocation_evidence" => 3
        },
        risk_level: "low",
        detector_version: "test_v1"
      },
      overrides
    )
  end
end
