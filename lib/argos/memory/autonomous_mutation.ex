defmodule Argos.Memory.AutonomousMutation do
  @moduledoc """
  Audit row for an autonomous canon mutation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Intelligence.Proposal
  alias Argos.Memory.Canon

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(
    proposal_id
    canon
    prior_canon_id
    new_canon_id
    prior_canon_version
    new_canon_version
    autonomy_policy_snapshot
    reasoning_trace
    applied_at
    rollback_expires_at
  )a
  @optional_fields ~w(rolled_back_at rollback_reason rollback_canon_id)a

  schema "autonomous_mutations" do
    field :canon, :string
    field :prior_canon_version, :integer
    field :new_canon_version, :integer
    field :autonomy_policy_snapshot, :map
    field :reasoning_trace, :map
    field :applied_at, :utc_datetime_usec
    field :rollback_expires_at, :utc_datetime_usec
    field :rolled_back_at, :utc_datetime_usec
    field :rollback_reason, :string

    belongs_to :proposal, Proposal
    belongs_to :prior_canon, Canon
    belongs_to :new_canon, Canon
    belongs_to :rollback_canon, Canon

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(mutation, attrs) do
    mutation
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:prior_canon_version, greater_than: 0)
    |> validate_number(:new_canon_version, greater_than: 0)
    |> validate_change(:autonomy_policy_snapshot, &validate_map/2)
    |> validate_change(:reasoning_trace, &validate_map/2)
    |> foreign_key_constraint(:proposal_id)
    |> foreign_key_constraint(:prior_canon_id)
    |> foreign_key_constraint(:new_canon_id)
    |> foreign_key_constraint(:rollback_canon_id)
    |> unique_constraint(:proposal_id)
  end

  def rollback_changeset(mutation, attrs) do
    mutation
    |> cast(attrs, [:rolled_back_at, :rollback_reason, :rollback_canon_id])
    |> validate_required([:rolled_back_at, :rollback_reason, :rollback_canon_id])
    |> foreign_key_constraint(:rollback_canon_id)
  end

  defp validate_map(field, value) do
    if is_map(value), do: [], else: [{field, "must be a map"}]
  end
end
