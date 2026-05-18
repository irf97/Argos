defmodule ArgosWeb.ApprovalQueueLiveTest do
  use ArgosWeb.ConnCase, async: true

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
end
