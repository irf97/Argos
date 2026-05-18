defmodule Argos.Adaptive.OutcomeScore do
  @moduledoc """
  Inspectable score for an outcome.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Arms.Outcome
  alias Argos.Context.ContextPack

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outcome_scores" do
    field :canon, :string
    field :score, :integer
    field :grade, :string
    field :rule_version, :string
    field :rules_applied, :map, default: %{}
    field :explanation, :string
    field :policy_metadata, :map, default: %{}
    field :scored_at, :utc_datetime_usec

    belongs_to :outcome, Outcome
    belongs_to :context_pack, ContextPack

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(outcome_score, attrs) do
    outcome_score
    |> cast(attrs, [
      :outcome_id,
      :context_pack_id,
      :canon,
      :score,
      :grade,
      :rule_version,
      :rules_applied,
      :explanation,
      :policy_metadata,
      :scored_at
    ])
    |> validate_required([
      :outcome_id,
      :context_pack_id,
      :canon,
      :score,
      :grade,
      :rule_version,
      :rules_applied,
      :explanation,
      :policy_metadata,
      :scored_at
    ])
    |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:grade, ["excellent", "good", "partial", "poor"])
    |> foreign_key_constraint(:outcome_id)
    |> foreign_key_constraint(:context_pack_id)
    |> unique_constraint(:outcome_id)
  end
end
