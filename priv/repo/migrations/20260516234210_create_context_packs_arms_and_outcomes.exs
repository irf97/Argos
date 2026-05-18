defmodule Argos.Repo.Migrations.CreateContextPacksArmsAndOutcomes do
  use Ecto.Migration

  def change do
    create table(:context_packs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :hash, :string, null: false
      add :task, :text, null: false
      add :canon, :string, null: false
      add :canon_versions, :map, null: false, default: %{}
      add :operator_state_id, :binary_id
      add :retrieval_policy, :map, null: false, default: %{}
      add :skill_refs, :map, null: false, default: %{}
      add :payload, :map, null: false
      add :markdown, :text, null: false
      add :compiled_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:context_packs, [:hash])
    create index(:context_packs, [:canon, :compiled_at])

    create table(:arms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :authority, :string, null: false
      add :config, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:arms, [:slug])

    create table(:arm_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :arm, :string, null: false
      add :project, :string, null: false
      add :task, :text, null: false

      add :context_pack_id, references(:context_packs, type: :binary_id, on_delete: :restrict),
        null: false

      add :started_at, :utc_datetime_usec, null: false
      add :ended_at, :utc_datetime_usec
      add :status, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:arm_sessions, [:arm, :status])
    create index(:arm_sessions, [:context_pack_id])

    create table(:outcomes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :arm_session_id, references(:arm_sessions, type: :binary_id, on_delete: :restrict),
        null: false

      add :context_pack_id, references(:context_packs, type: :binary_id, on_delete: :restrict),
        null: false

      add :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)
      add :result, :string, null: false
      add :summary, :text, null: false
      add :metrics, :map, null: false, default: %{}
      add :artifacts, :map, null: false, default: %{}
      add :captured_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:outcomes, [:arm_session_id])
    create index(:outcomes, [:context_pack_id])
    create index(:outcomes, [:event_id])
  end
end
