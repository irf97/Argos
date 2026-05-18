defmodule ArgosWeb.Api.ContextPackControllerTest do
  use ArgosWeb.ConnCase, async: true

  test "POST /api/context-pack creates a context pack", %{conn: conn} do
    conn =
      post(conn, ~p"/api/context-pack", %{
        "canon" => "operator",
        "task" => "build context",
        "project" => "argos",
        "arm" => "codex_cli"
      })

    assert %{
             "context_pack" => %{
               "id" => id,
               "hash" => hash,
               "markdown" => markdown,
               "payload" => %{"provenance" => %{"compiler_version" => "context_pack_v1"}}
             }
           } = json_response(conn, 201)

    assert id
    assert String.length(hash) == 64
    assert markdown =~ "# Task"
  end

  test "GET /api/context-pack/:hash returns a pack", %{conn: conn} do
    conn =
      post(conn, ~p"/api/context-pack", %{
        "canon" => "operator",
        "task" => "fetch context"
      })

    hash = json_response(conn, 201)["context_pack"]["hash"]

    conn = get(build_conn(), ~p"/api/context-pack/#{hash}")

    assert %{"context_pack" => %{"hash" => ^hash, "task" => "fetch context"}} =
             json_response(conn, 200)
  end
end
