defmodule Argos.Repo.Migrations.CreateDoctrineChunks do
  use Ecto.Migration

  def change do
    create table(:doctrine_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :canon, :string, null: false
      add :canon_version, :integer
      add :source, :string, null: false
      add :source_id, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :metadata, :map, null: false, default: %{}
      add :content_hash, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:doctrine_chunks, [:content_hash])
    create index(:doctrine_chunks, [:canon, :canon_version])

    execute """
            ALTER TABLE doctrine_chunks
            ADD COLUMN search_vector tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
            ) STORED;
            """,
            "ALTER TABLE doctrine_chunks DROP COLUMN search_vector;"

    execute "CREATE INDEX doctrine_chunks_search_vector_idx ON doctrine_chunks USING GIN (search_vector);",
            "DROP INDEX doctrine_chunks_search_vector_idx;"
  end
end
