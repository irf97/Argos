defmodule ArgosWeb.Api.ProposalControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Intelligence.Proposals

  test "POST /api/proposals/detect creates proposals", %{conn: conn} do
    conn =
      post(conn, ~p"/api/proposals/detect", %{
        "canon" => "operator",
        "detectors" => ["contradiction"],
        "claims" => [
          %{"topic" => "authority", "value" => "operator_only"},
          %{"topic" => "authority", "value" => "autonomous"}
        ]
      })

    assert %{
             "proposals" => [
               %{
                 "type" => "contradiction",
                 "approval_id" => approval_id,
                 "approval_status" => "pending",
                 "proposed_action" => %{"autonomous_action" => false}
               }
             ],
             "errors" => []
           } = json_response(conn, 201)

    assert approval_id
  end

  test "GET /api/proposals lists proposals", %{conn: conn} do
    [{:ok, proposal}] =
      Proposals.detect(%{
        "canon" => "operator",
        "detectors" => ["gap"],
        "required_topics" => ["security"],
        "present_topics" => []
      })

    conn = get(conn, ~p"/api/proposals?status=pending")

    assert %{"proposals" => [%{"id" => id, "type" => "gap"}]} = json_response(conn, 200)
    assert id == proposal.id
  end
end
