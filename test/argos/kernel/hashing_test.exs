defmodule Argos.Kernel.HashingTest do
  use ExUnit.Case, async: true

  alias Argos.Kernel.Hashing

  test "canonical_json sorts object keys recursively" do
    left = %{"b" => 2, "a" => %{"d" => 4, "c" => 3}}
    right = %{"a" => %{"c" => 3, "d" => 4}, "b" => 2}

    assert Hashing.canonical_json(left) == ~s({"a":{"c":3,"d":4},"b":2})
    assert Hashing.canonical_json(left) == Hashing.canonical_json(right)
  end

  test "event_hash is deterministic for equivalent event maps" do
    occurred_at = DateTime.from_naive!(~N[2026-05-17 00:00:00.000000], "Etc/UTC")

    first = %{
      kind: "manual_note",
      canon: "operator",
      source: "test",
      payload: %{"b" => 2, "a" => 1},
      prev_hash: nil,
      author: "operator",
      occurred_at: occurred_at
    }

    second = %{
      "author" => "operator",
      "canon" => "operator",
      "kind" => "manual_note",
      "occurred_at" => "2026-05-17T00:00:00.000000Z",
      "payload" => %{"a" => 1, "b" => 2},
      "prev_hash" => nil,
      "source" => "test"
    }

    assert Hashing.event_hash(first) == Hashing.event_hash(second)
    assert String.length(Hashing.event_hash(first)) == 64
  end
end
