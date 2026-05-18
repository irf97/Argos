defmodule Argos.ArmsTest do
  use Argos.DataCase, async: true

  alias Argos.Arms
  alias Argos.Context.Packs
  alias Argos.Memory.Events

  test "start_session creates an active session and session-start event" do
    {:ok, pack} = create_pack()

    assert {:ok, session} =
             Arms.start_session(%{
               arm: "codex_cli",
               project: "argos",
               task: "work",
               context_pack_id: pack.id,
               author: "operator"
             })

    assert session.status == "active"
    assert session.context_pack_id == pack.id

    assert "codex_session_started" in event_kinds()
  end

  test "end_session marks a session ended and emits session-end event" do
    {:ok, pack} = create_pack()
    {:ok, session} = start_session(pack)

    assert {:ok, ended_session} =
             Arms.end_session(%{
               arm_session_id: session.id,
               status: "ended",
               summary: "done",
               metrics: %{"test_status" => "pass"},
               artifacts: %{"changed_files" => []},
               author: "operator"
             })

    assert ended_session.status == "ended"
    assert ended_session.ended_at
    assert "codex_session_ended" in event_kinds()
  end

  test "create_outcome links session, context pack, and event" do
    {:ok, pack} = create_pack()
    {:ok, session} = start_session(pack)

    assert {:ok, outcome} =
             Arms.create_outcome(%{
               arm_session_id: session.id,
               context_pack_id: pack.id,
               result: "success",
               summary: "Tests passed.",
               metrics: %{"test_status" => "pass"},
               artifacts: %{"changed_files" => []},
               author: "operator"
             })

    assert outcome.event_id
    assert outcome.context_pack_id == pack.id
    assert outcome.arm_session_id == session.id
    assert "codex_outcome" in event_kinds()
  end

  test "create_outcome rejects mismatched session/context pack" do
    {:ok, first_pack} = create_pack(%{task: "first"})
    {:ok, second_pack} = create_pack(%{task: "second"})
    {:ok, session} = start_session(first_pack)

    assert {:error, :context_pack_mismatch} =
             Arms.create_outcome(%{
               arm_session_id: session.id,
               context_pack_id: second_pack.id,
               result: "success",
               summary: "wrong pack"
             })
  end

  defp create_pack(overrides \\ %{}) do
    attrs = Map.merge(%{canon: "operator", task: "work", project: "argos"}, overrides)
    Packs.create_pack(attrs)
  end

  defp start_session(pack) do
    Arms.start_session(%{
      arm: "codex_cli",
      project: "argos",
      task: pack.task,
      context_pack_id: pack.id,
      author: "operator"
    })
  end

  defp event_kinds do
    Events.list_events(canon: "operator") |> Enum.map(& &1.kind)
  end
end
