defmodule ArgosWeb.Api.OutcomeControllerTest do
  use ArgosWeb.ConnCase, async: true

  alias Argos.Arms
  alias Argos.Context.Packs

  test "POST /api/outcomes creates a linked outcome", %{conn: conn} do
    {:ok, pack} = Packs.create_pack(%{canon: "operator", task: "outcome"})

    {:ok, session} =
      Arms.start_session(%{
        arm: "codex_cli",
        project: "argos",
        task: "outcome",
        context_pack_id: pack.id
      })

    conn =
      post(conn, ~p"/api/outcomes", %{
        "arm_session_id" => session.id,
        "context_pack_id" => pack.id,
        "result" => "success",
        "summary" => "Tests passed.",
        "metrics" => %{"test_status" => "pass"},
        "artifacts" => %{"changed_files" => []}
      })

    assert %{
             "outcome" => %{
               "event_id" => event_id,
               "result" => "success",
               "score" => %{"score" => 100, "grade" => "excellent"}
             }
           } =
             json_response(conn, 201)

    assert event_id
  end

  test "POST /api/outcomes rejects invalid result", %{conn: conn} do
    {:ok, pack} = Packs.create_pack(%{canon: "operator", task: "outcome"})

    {:ok, session} =
      Arms.start_session(%{
        arm: "codex_cli",
        project: "argos",
        task: "outcome",
        context_pack_id: pack.id
      })

    conn =
      post(conn, ~p"/api/outcomes", %{
        "arm_session_id" => session.id,
        "context_pack_id" => pack.id,
        "result" => "unknown",
        "summary" => "bad"
      })

    assert %{"errors" => %{"result" => [_ | _]}} = json_response(conn, 422)
  end
end
