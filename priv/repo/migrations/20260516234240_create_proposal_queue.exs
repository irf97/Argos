defmodule Argos.Repo.Migrations.CreateProposalQueue do
  use Ecto.Migration

  def change do
    create table(:proposal_queue, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :canon, :string, null: false
      add :canon_version, :integer
      add :status, :string, null: false, default: "pending"
      add :title, :string, null: false
      add :summary, :text, null: false
      add :evidence, :map, null: false, default: %{}
      add :proposed_action, :map, null: false, default: %{}
      add :risk_level, :string, null: false
      add :approval_id, references(:approvals, type: :binary_id, on_delete: :nilify_all)
      add :detector_version, :string, null: false
      add :dedupe_hash, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:proposal_queue, [:status])
    create index(:proposal_queue, [:canon, :type])
    create unique_index(:proposal_queue, [:dedupe_hash])
    create index(:proposal_queue, [:approval_id])
  end
end
