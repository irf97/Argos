defmodule ArgosWeb.Api.CrawlControllerTest do
  use ArgosWeb.ConnCase, async: true

  test "POST /api/crawl creates a queued local prompt packet", %{conn: conn} do
    seek = %{
      "use_case" => "expert discovery",
      "domain" => "local robotics",
      "geography" => "Enschede",
      "max_count" => 5
    }

    conn = post(conn, ~p"/api/crawl", %{"seek" => seek, "author" => "operator"})

    assert %{
             "crawl_job" => %{
               "id" => id,
               "kind" => "crawl",
               "status" => "queued",
               "seek" => ^seek,
               "prompt" => prompt,
               "event_id" => nil
             }
           } = json_response(conn, 201)

    assert id
    assert prompt =~ "local robotics"
  end

  test "POST /api/crawl-and-ingest persists normalized records and an event", %{conn: conn} do
    record = %{
      "name" => "Local Robotics Lab",
      "source_url" => "https://example.test/lab",
      "notes" => "public source"
    }

    conn =
      post(conn, ~p"/api/crawl-and-ingest", %{
        "canon" => "operator",
        "seek" => %{"domain" => "robotics"},
        "records" => [record],
        "raw_output" => %{"records" => [record]},
        "author" => "codex"
      })

    response = json_response(conn, 201)

    assert %{
             "crawl_job" => %{
               "id" => job_id,
               "kind" => "crawl_and_ingest",
               "status" => "completed",
               "event_id" => event_id,
               "normalized_records" => %{
                 "count" => 1,
                 "records" => [%{"name" => "Local Robotics Lab", "record_id" => record_id}]
               }
             },
             "event" => %{
               "kind" => "crawl_ingested",
               "payload" => %{"record_count" => 1}
             }
           } = response

    assert response["event"]["id"] == event_id
    assert response["event"]["payload"]["crawl_job_id"] == job_id

    assert record_id

    conn = get(build_conn(), ~p"/api/crawl-jobs/#{job_id}")

    assert %{"crawl_job" => %{"id" => ^job_id, "event_id" => ^event_id}} =
             json_response(conn, 200)
  end

  test "POST /api/crawl-and-ingest requires records", %{conn: conn} do
    conn = post(conn, ~p"/api/crawl-and-ingest", %{"seek" => %{"domain" => "robotics"}})

    assert %{"errors" => %{"records" => ["are required"]}} = json_response(conn, 422)
  end
end
