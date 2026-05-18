defmodule Argos.Context.ContextPack do
  @moduledoc """
  Persisted context pack compiled for an external arm.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(hash task canon canon_versions retrieval_policy skill_refs payload markdown compiled_at)a
  @optional_fields [:operator_state_id]
  @hash_format ~r/\A[0-9a-f]{64}\z/

  schema "context_packs" do
    field :hash, :string
    field :task, :string
    field :canon, :string
    field :canon_versions, :map, default: %{}
    field :operator_state_id, :binary_id
    field :retrieval_policy, :map, default: %{}
    field :skill_refs, :map, default: %{}
    field :payload, :map
    field :markdown, :string
    field :compiled_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(context_pack, attrs) do
    context_pack
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:hash, @hash_format)
    |> validate_change(:payload, &validate_map/2)
    |> validate_change(:canon_versions, &validate_map/2)
    |> validate_change(:retrieval_policy, &validate_map/2)
    |> validate_change(:skill_refs, &validate_map/2)
    |> unique_constraint(:hash)
  end

  defp validate_map(field, value) do
    if is_map(value), do: [], else: [{field, "must be a map"}]
  end
end
