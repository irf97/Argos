defmodule ArgosWeb.Api.CrawlController do
  use ArgosWeb, :controller

  alias Argos.Ingest.CrawlJobs
  alias Argos.MCP.Tools

  def index(conn, params) do
    opts =
      []
      |> maybe_put(:status, Map.get(params, "status"))
      |> maybe_put(:limit, parse_limit(Map.get(params, "limit")))

    jobs = CrawlJobs.list_jobs(opts)
    json(conn, %{crawl_jobs: Enum.map(jobs, &Tools.crawl_job_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case CrawlJobs.get_job(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "crawl job not found"})

      job ->
        json(conn, %{crawl_job: Tools.crawl_job_json(job)})
    end
  end

  def create(conn, params) do
    case CrawlJobs.create_crawl(params) do
      {:ok, job} ->
        conn
        |> put_status(:created)
        |> json(%{crawl_job: Tools.crawl_job_json(job)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  def crawl_and_ingest(conn, params) do
    case CrawlJobs.crawl_and_ingest(params) do
      {:ok, %{job: job, event: event}} ->
        conn
        |> put_status(:created)
        |> json(%{crawl_job: Tools.crawl_job_json(job), event: event_json(event)})

      {:error, :records_required} ->
        validation_error(conn, :records, "are required")

      {:error, :invalid_record} ->
        validation_error(conn, :records, "must contain objects")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  defp event_json(event) do
    %{
      id: event.id,
      kind: event.kind,
      canon: event.canon,
      source: event.source,
      payload: event.payload,
      prev_hash: event.prev_hash,
      hash: event.hash,
      author: event.author,
      occurred_at: DateTime.to_iso8601(event.occurred_at),
      inserted_at: DateTime.to_iso8601(event.inserted_at)
    }
  end

  defp validation_error(conn, field, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{field => [message]}})
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_limit(nil), do: nil
  defp parse_limit(""), do: nil

  defp parse_limit(limit) do
    case Integer.parse(limit) do
      {integer, ""} -> integer
      _invalid -> nil
    end
  end
end
