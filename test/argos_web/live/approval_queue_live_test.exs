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
            "practice" => "patterns",
            "target" => "constellation"
          }
        },
        "risk_level" => "medium",
        "detector_version" => "mcp_v1"
      })

    {:ok, view, html} = live(conn, ~p"/approvals")

    assert html =~ "ikuzo-greenlight"
    assert html =~ "mcp_v1"
    assert html =~ "MCP-submitted proposal."
    assert html =~ "Observation"
    assert html =~ "Binding"
    assert html =~ "Initial failure modes"
    assert html =~ "Where it lives after approval"
    assert html =~ "Constellation sync is not wired yet"

    view
    |> element("#approval-#{proposal.approval_id} button", "Approve")
    |> render_click()

    html = render(view)
    assert html =~ "Recent decisions"
    assert html =~ "ikuzo-greenlight"
    assert html =~ "Stored in ARGOS Postgres"
    assert Proposals.get_proposal!(proposal.id).status == "reviewed"
  end
end
