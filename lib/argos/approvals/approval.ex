defmodule Argos.Approvals.Approval do
  @moduledoc """
  Operator approval request.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(subject_type subject_id action risk_level status proposal)a
  @optional_fields ~w(reason decided_by decided_at)a

  schema "approvals" do
    field :subject_type, :string
    field :subject_id, :binary_id
    field :action, :string
    field :risk_level, :string
    field :status, :string, default: "pending"
    field :proposal, :map
    field :reason, :string
    field :decided_by, :string
    field :decided_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(approval, attrs) do
    approval
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:risk_level, ["low", "medium", "high", "critical"])
    |> validate_inclusion(:status, ["pending", "approved", "rejected", "expired"])
    |> validate_change(:proposal, fn :proposal, proposal ->
      if is_map(proposal), do: [], else: [proposal: "must be a map"]
    end)
  end

  def decision_changeset(approval, attrs) do
    approval
    |> cast(attrs, [:status, :decided_by, :decided_at])
    |> validate_required([:status, :decided_by, :decided_at])
    |> validate_inclusion(:status, ["approved", "rejected"])
  end
end
