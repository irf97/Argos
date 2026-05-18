defmodule Argos.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :canon, :string, null: false
      add :source, :string, null: false
      add :payload, :map, null: false
      add :prev_hash, :string
      add :hash, :string, null: false
      add :author, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:events, [:hash])
    create index(:events, [:canon, :occurred_at])
    create index(:events, [:kind])
    create index(:events, [:source])

    execute """
            CREATE OR REPLACE FUNCTION prevent_events_update_delete()
            RETURNS trigger AS $$
            BEGIN
              RAISE EXCEPTION 'events are append-only';
            END;
            $$ LANGUAGE plpgsql;
            """,
            "DROP FUNCTION IF EXISTS prevent_events_update_delete();"

    execute """
            CREATE TRIGGER events_append_only
            BEFORE UPDATE OR DELETE ON events
            FOR EACH ROW EXECUTE FUNCTION prevent_events_update_delete();
            """,
            "DROP TRIGGER IF EXISTS events_append_only ON events;"
  end
end
