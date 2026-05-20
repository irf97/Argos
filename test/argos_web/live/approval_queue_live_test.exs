defmodule ArgosWeb.ApprovalQueueLiveTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Intelligence.Proposals
  alias Argos.Memory.Canons

  test "renders pending approvals", %{conn: conn} do
    {:ok, _approval} =
      Canons.draft_canon("operator", %{
        state: %{"principle" => "approval required"},
        reason: "operator review"
      })

    {:ok, _view, html} = live(conn, ~p"/approvals")

    assert html =~ "Approval queue"
    assert html =~ "operator review"
    assert html =~ "canon_commit"
  end

  test "renders proposal details and can approve proposal reviews", %{conn: conn} do
    {:ok, proposal} =
      Proposals.create_proposal(%{
        "type" => "canon_update",
        "canon" => "operator",
        "title" => "ikuzo-greenlight",
        "summary" => "MCP-submitted proposal.",
        "evidence" => %{"source" => "test"},
        "proposed_action" => %{
          "kind" => "canon_update",
          "body" => %{
            "name" => "ikuzo-greenlight",
            "practice" => "patterns"
          }
        },
        "risk_level" => "medium",
        "detector_version" => "mcp_v1"
      })

    {:ok, view, html} = live(conn, ~p"/approvals")

    assert html =~ "ikuzo-greenlight"
    assert html =~ "mcp_v1"
    assert html =~ "MCP-submitted proposal."

    view
    |> element("#approval-#{proposal.approval_id} button", "Approve")
    |> render_click()

    refute render(view) =~ "ikuzo-greenlight"
    assert Proposals.get_proposal!(proposal.id).status == "reviewed"
  end
end
