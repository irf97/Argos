defmodule ArgosWeb.Api.ArmSessionControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Context.Packs

  test "POST /api/arms/session/start creates a session", %{conn: conn} do
    {:ok, pack} = Packs.create_pack(%{canon: "operator", task: "session start"})

    conn =
      post(conn, ~p"/api/arms/session/start", %{
        "arm" => "codex_cli",
        "project" => "argos",
        "task" => "session start",
        "context_pack_id" => pack.id,
        "author" => "operator"
      })

    assert %{"arm_session" => %{"id" => id, "status" => "active"}} = json_response(conn, 201)
    assert id
  end

  test "POST /api/arms/session/end ends a session", %{conn: conn} do
    {:ok, pack} = Packs.create_pack(%{canon: "operator", task: "session end"})

    conn =
      post(conn, ~p"/api/arms/session/start", %{
        "arm" => "codex_cli",
        "project" => "argos",
        "task" => "session end",
        "context_pack_id" => pack.id
      })

    session_id = json_response(conn, 201)["arm_session"]["id"]

    conn =
      post(build_conn(), ~p"/api/arms/session/end", %{
        "arm_session_id" => session_id,
        "status" => "ended",
        "summary" => "done"
      })

    assert %{"arm_session" => %{"id" => ^session_id, "status" => "ended"}} =
             json_response(conn, 200)
  end
end
