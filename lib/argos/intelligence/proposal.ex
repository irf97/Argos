defmodule Argos.Intelligence.Proposal do
  @moduledoc """
  Proposal queue entry. Proposals request operator review; they do not act.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Approvals.Approval

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(type canon status title summary evidence proposed_action risk_level detector_version dedupe_hash)a
  @optional_fields [:canon_version, :approval_id]
  @hash_format ~r/\A[0-9a-f]{64}\z/

  schema "proposal_queue" do
    field :type, :string
    field :canon, :string
    field :canon_version, :integer
    field :status, :string, default: "pending"
    field :title, :string
    field :summary, :string
    field :evidence, :map, default: %{}
    field :proposed_action, :map, default: %{}
    field :risk_level, :string
    field :detector_version, :string
    field :dedupe_hash, :string

    belongs_to :approval, Approval

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, [
      "canon_update",
      "contradiction",
      "contradiction_resolution",
      "experiment",
      "gap",
      "gap_fill",
      "policy_update"
    ])
    |> validate_inclusion(:status, [
      "pending",
      "reviewed",
      "dismissed",
      "auto_applied",
      "rolled_back"
    ])
    |> validate_inclusion(:risk_level, ["low", "medium", "high", "critical"])
    |> validate_format(:dedupe_hash, @hash_format)
    |> validate_change(:evidence, &validate_map/2)
    |> validate_change(:proposed_action, &validate_map/2)
    |> foreign_key_constraint(:approval_id)
    |> unique_constraint(:dedupe_hash)
  end

  defp validate_map(field, value) do
    if is_map(value), do: [], else: [{field, "must be a map"}]
  end
end
