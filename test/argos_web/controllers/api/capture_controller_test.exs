defmodule ArgosWeb.Api.CaptureControllerTest do
  use ArgosWeb.ConnCase, async: true

  test "POST /api/capture appends an event", %{conn: conn} do
    conn = post(conn, ~p"/api/capture", event_params(%{"text" => "captured"}))

    assert %{
             "event" => %{
               "kind" => "manual_note",
               "canon" => "operator",
               "source" => "api_test",
               "payload" => %{"text" => "captured"},
               "prev_hash" => nil,
               "hash" => hash
             }
           } = json_response(conn, 201)

    assert String.length(hash) == 64
  end

  test "POST /api/capture rejects malformed payloads", %{conn: conn} do
    params = event_params("raw text")

    conn = post(conn, ~p"/api/capture", params)

    assert %{"errors" => %{"payload" => [_message | _]}} = json_response(conn, 422)
  end

  defp event_params(payload) do
    %{
      "kind" => "manual_note",
      "canon" => "operator",
      "source" => "api_test",
      "payload" => payload,
      "author" => "operator",
      "occurred_at" => "2026-05-17T00:00:00.000000Z"
    }
  end
end
