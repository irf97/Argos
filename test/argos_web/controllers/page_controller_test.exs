defmodule ArgosWeb.PageControllerTest do
  use ArgosWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Operator memory substrate"
    assert html_response(conn, 200) =~ "Outcome scoring"
    assert html_response(conn, 200) =~ "scored outcomes"
    assert html_response(conn, 200) =~ "Proposals"
    assert html_response(conn, 200) =~ "pending proposals"
    assert html_response(conn, 200) =~ "Autonomous mutations"
    assert html_response(conn, 200) =~ "24h rollback window"
  end
end
