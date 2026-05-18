defmodule Argos.Context.DoctrineChunk do
  @moduledoc """
  Searchable doctrine/context source chunk.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(canon source source_id title body metadata content_hash)a
  @optional_fields [:canon_version]
  @hash_format ~r/\A[0-9a-f]{64}\z/

  schema "doctrine_chunks" do
    field :canon, :string
    field :canon_version, :integer
    field :source, :string
    field :source_id, :string
    field :title, :string
    field :body, :string
    field :metadata, :map, default: %{}
    field :content_hash, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:canon_version, greater_than: 0)
    |> validate_format(:content_hash, @hash_format)
    |> validate_change(:metadata, fn :metadata, metadata ->
      if is_map(metadata), do: [], else: [metadata: "must be a map"]
    end)
    |> unique_constraint(:content_hash)
  end
end
