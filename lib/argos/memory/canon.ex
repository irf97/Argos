defmodule Argos.Memory.Canon do
  @moduledoc """
  Immutable approved canon version.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @default_autonomy_policy %{
    "mode" => "require_approval",
    "allowed_proposal_kinds" => [],
    "severity_ceiling" => "low",
    "daily_cap" => 0,
    "min_invocation_evidence" => 0,
    "min_confidence" => "user-confirmed"
  }

  @required_fields ~w(name version state autonomy_policy hash status approved_by approved_at)a
  @optional_fields [:ancestor_hash]
  @hash_format ~r/\A[0-9a-f]{64}\z/

  schema "canons" do
    field :name, :string
    field :version, :integer
    field :state, :map
    field :autonomy_policy, :map, default: @default_autonomy_policy
    field :ancestor_hash, :string
    field :hash, :string
    field :status, :string, default: "approved"
    field :approved_by, :string
    field :approved_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def default_autonomy_policy, do: @default_autonomy_policy

  def changeset(canon, attrs) do
    canon
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["approved"])
    |> validate_number(:version, greater_than: 0)
    |> validate_format(:hash, @hash_format)
    |> validate_format(:ancestor_hash, @hash_format)
    |> validate_change(:state, fn :state, state ->
      if is_map(state), do: [], else: [state: "must be a map"]
    end)
    |> validate_change(:autonomy_policy, fn :autonomy_policy, autonomy_policy ->
      if is_map(autonomy_policy), do: [], else: [autonomy_policy: "must be a map"]
    end)
    |> unique_constraint([:name, :version])
    |> unique_constraint(:hash)
  end
end
