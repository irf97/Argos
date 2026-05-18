defmodule Argos.Memory.EventsTest do
  use Argos.DataCase, async: true

  alias Argos.Memory.Events

  describe "append_event/1" do
    test "appends events and links hashes per canon" do
      assert {:ok, first_event} =
               Events.append_event(event_attrs(%{payload: %{"text" => "first"}}))

      assert first_event.prev_hash == nil
      assert String.length(first_event.hash) == 64

      assert {:ok, second_event} =
               Events.append_event(
                 event_attrs(%{
                   payload: %{"text" => "second"},
                   occurred_at: utc_datetime(1)
                 })
               )

      assert second_event.prev_hash == first_event.hash
      assert :ok = Events.validate_chain("operator")
    end

    test "keeps independent chains per canon" do
      assert {:ok, operator_event} = Events.append_event(event_attrs())

      assert {:ok, project_event} =
               Events.append_event(
                 event_attrs(%{canon: "project", payload: %{"text" => "project"}})
               )

      assert operator_event.prev_hash == nil
      assert project_event.prev_hash == nil
    end

    test "rejects a caller supplied wrong prev_hash" do
      assert {:ok, _event} = Events.append_event(event_attrs())

      assert {:error, changeset} =
               Events.append_event(
                 event_attrs(%{
                   payload: %{"text" => "wrong link"},
                   prev_hash: String.duplicate("0", 64),
                   occurred_at: utc_datetime(1)
                 })
               )

      assert "does not match latest event hash" in errors_on(changeset).prev_hash
    end

    test "rejects malformed payloads" do
      assert {:error, changeset} = Events.append_event(event_attrs(%{payload: "raw text"}))

      assert "is invalid" in errors_on(changeset).payload
    end

    test "prevents event mutation at the database layer" do
      assert {:ok, event} = Events.append_event(event_attrs())

      assert_raise Postgrex.Error, ~r/events are append-only/, fn ->
        event
        |> change(source: "changed")
        |> Repo.update!()
      end
    end
  end

  describe "validate_chain/1" do
    test "rejects wrong prev_hash in a supplied event list" do
      assert {:ok, first_event} = Events.append_event(event_attrs())

      broken_event = %{
        first_event
        | id: Ecto.UUID.generate(),
          payload: %{"text" => "broken"},
          prev_hash: String.duplicate("1", 64)
      }

      broken_event_id = broken_event.id

      assert {:error, {:prev_hash_mismatch, ^broken_event_id}} =
               Events.validate_chain([first_event, broken_event])
    end
  end

  defp event_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "manual_note",
        canon: "operator",
        source: "test",
        payload: %{"text" => "note"},
        author: "operator",
        occurred_at: utc_datetime(0)
      },
      overrides
    )
  end

  defp utc_datetime(seconds) do
    ~N[2026-05-17 00:00:00.000000]
    |> NaiveDateTime.add(seconds, :second)
    |> DateTime.from_naive!("Etc/UTC")
  end
end
