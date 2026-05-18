defmodule Argos.Repo.Migrations.CreateCrawlJobs do
  use Ecto.Migration

  def change do
    create table(:crawl_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :status, :string, null: false
      add :seek, :map, null: false, default: %{}
      add :prompt, :text, null: false
      add :raw_input, :map, null: false, default: %{}
      add :raw_output, :map, null: false, default: %{}
      add :normalized_records, :map, null: false, default: %{}
      add :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)
      add :error, :text
      add :requested_at, :utc_datetime_usec, null: false
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:crawl_jobs, [:status, :requested_at])
    create index(:crawl_jobs, [:event_id])
  end
end
