defmodule ArgosWeb.Api.CanonControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Approvals
  alias Argos.Memory.Canons

  test "POST /api/canon/:name/draft creates a canon approval", %{conn: conn} do
    conn =
      post(conn, ~p"/api/canon/operator/draft", %{
        "state" => %{"principle" => "local-first"},
        "author" => "operator",
        "reason" => "initial"
      })

    assert %{
             "approval" => %{
               "status" => "pending",
               "action" => "canon_commit",
               "proposal" => %{"name" => "operator", "version" => 1}
             }
           } = json_response(conn, 201)
  end

  test "GET /api/canon/:name returns latest approved canon", %{conn: conn} do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})
    {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

    conn = get(conn, ~p"/api/canon/operator")

    assert %{"canon" => %{"id" => id, "version" => 1, "status" => "approved"}} =
             json_response(conn, 200)

    assert id == canon.id
  end

  test "GET /api/canon/:name returns 404 when missing", %{conn: conn} do
    conn = get(conn, ~p"/api/canon/missing")

    assert %{"error" => "canon not found"} = json_response(conn, 404)
  end
end
