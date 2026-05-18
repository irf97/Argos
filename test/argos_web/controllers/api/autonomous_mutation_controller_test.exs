defmodule ArgosWeb.Api.AutonomousMutationControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.Canons

  test "GET /api/autonomous-mutations lists audit rows", %{conn: conn} do
    {:ok, proposal} = create_autonomous_mutation()

    conn = get(conn, ~p"/api/autonomous-mutations")

    assert %{
             "autonomous_mutations" => [
               %{"proposal_id" => proposal_id, "new_canon_version" => 2}
             ]
           } = json_response(conn, 200)

    assert proposal_id == proposal.id
  end

  test "POST /api/autonomous-mutations/:proposal_id/rollback rolls back", %{conn: conn} do
    {:ok, proposal} = create_autonomous_mutation()

    conn =
      post(conn, ~p"/api/autonomous-mutations/#{proposal.id}/rollback", %{
        "operator" => "operator",
        "reason" => "operator rejected automatic mutation"
      })

    assert %{
             "autonomous_mutation" => %{
               "rollback_reason" => "operator rejected automatic mutation"
             },
             "rollback_canon" => %{
               "version" => 3,
               "state" => %{"principle" => "bounded autonomy"}
             },
             "proposal" => %{"status" => "rolled_back"}
           } = json_response(conn, 200)
  end

  defp create_autonomous_mutation do
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

    {:ok, _approval, _canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

    Proposals.create_proposal(%{
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
    })
  end
end
