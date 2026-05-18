defmodule Argos.Repo.Migrations.CreateCanonsAndApprovals do
  use Ecto.Migration

  def change do
    create table(:canons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :version, :integer, null: false
      add :state, :map, null: false
      add :ancestor_hash, :string
      add :hash, :string, null: false
      add :status, :string, null: false, default: "approved"
      add :approved_by, :string, null: false
      add :approved_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:canons, [:name, :version])
    create unique_index(:canons, [:hash])
    create index(:canons, [:name, :status])

    create table(:approvals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject_type, :string, null: false
      add :subject_id, :binary_id, null: false
      add :action, :string, null: false
      add :risk_level, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :proposal, :map, null: false
      add :reason, :text
      add :decided_by, :string
      add :decided_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:approvals, [:status])
    create index(:approvals, [:subject_type, :subject_id])

    execute """
            CREATE OR REPLACE FUNCTION prevent_canons_update_delete()
            RETURNS trigger AS $$
            BEGIN
              RAISE EXCEPTION 'canon versions are immutable';
            END;
            $$ LANGUAGE plpgsql;
            """,
            "DROP FUNCTION IF EXISTS prevent_canons_update_delete();"

    execute """
            CREATE TRIGGER canons_immutable
            BEFORE UPDATE OR DELETE ON canons
            FOR EACH ROW EXECUTE FUNCTION prevent_canons_update_delete();
            """,
            "DROP TRIGGER IF EXISTS canons_immutable ON canons;"
  end
end
