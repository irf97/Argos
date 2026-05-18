defmodule Argos.Repo.Migrations.CreateOutcomeScores do
  use Ecto.Migration

  def change do
    create table(:outcome_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :outcome_id, references(:outcomes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :context_pack_id, references(:context_packs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :canon, :string, null: false
      add :score, :integer, null: false
      add :grade, :string, null: false
      add :rule_version, :string, null: false
      add :rules_applied, :map, null: false, default: %{}
      add :explanation, :text, null: false
      add :policy_metadata, :map, null: false, default: %{}
      add :scored_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:outcome_scores, [:outcome_id])
    create index(:outcome_scores, [:context_pack_id])
    create index(:outcome_scores, [:canon])
  end
end
