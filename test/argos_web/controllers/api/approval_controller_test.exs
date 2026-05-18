defmodule ArgosWeb.Api.ApprovalControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Memory.Canons

  test "GET /api/approvals lists pending approvals", %{conn: conn} do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

    conn = get(conn, ~p"/api/approvals?status=pending")

    assert %{"approvals" => [%{"id" => id, "status" => "pending"}]} = json_response(conn, 200)
    assert id == approval.id
  end

  test "POST /api/approvals/:id/approve commits canon", %{conn: conn} do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

    conn = post(conn, ~p"/api/approvals/#{approval.id}/approve", %{"decided_by" => "operator"})

    assert %{
             "approval" => %{"status" => "approved"},
             "canon" => %{"name" => "operator", "version" => 1}
           } = json_response(conn, 200)
  end

  test "POST /api/approvals/:id/reject rejects without canon", %{conn: conn} do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

    conn = post(conn, ~p"/api/approvals/#{approval.id}/reject", %{"decided_by" => "operator"})

    assert %{"approval" => %{"status" => "rejected"}} = json_response(conn, 200)
  end
end
