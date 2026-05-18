defmodule Argos.Repo.Migrations.AddAutonomyPolicyAndAutonomousMutations do
  use Ecto.Migration

  def change do
    alter table(:canons) do
      add :autonomy_policy, :map,
        null: false,
        default: %{
          "mode" => "require_approval",
          "allowed_proposal_kinds" => [],
          "severity_ceiling" => "low",
          "daily_cap" => 0,
          "min_invocation_evidence" => 0,
          "min_confidence" => "user-confirmed"
        }
    end

    create table(:autonomous_mutations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :proposal_id, references(:proposal_queue, type: :binary_id, on_delete: :restrict),
        null: false

      add :canon, :string, null: false

      add :prior_canon_id, references(:canons, type: :binary_id, on_delete: :restrict),
        null: false

      add :new_canon_id, references(:canons, type: :binary_id, on_delete: :restrict), null: false
      add :prior_canon_version, :integer, null: false
      add :new_canon_version, :integer, null: false
      add :autonomy_policy_snapshot, :map, null: false
      add :reasoning_trace, :map, null: false
      add :applied_at, :utc_datetime_usec, null: false
      add :rollback_expires_at, :utc_datetime_usec, null: false
      add :rolled_back_at, :utc_datetime_usec
      add :rollback_reason, :text
      add :rollback_canon_id, references(:canons, type: :binary_id, on_delete: :restrict)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:autonomous_mutations, [:proposal_id])
    create index(:autonomous_mutations, [:canon, :applied_at])
    create index(:autonomous_mutations, [:rollback_expires_at])
  end
end
