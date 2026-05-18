defmodule Argos.Arms.Arm do
  @moduledoc """
  External execution arm registration.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @authorities ~w(
    observe_only
    suggest_only
    write_local
    write_repo
    execute_low_risk
    execute_high_risk
    financial_action
  )

  schema "arms" do
    field :slug, :string
    field :name, :string
    field :authority, :string
    field :config, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(arm, attrs) do
    arm
    |> cast(attrs, [:slug, :name, :authority, :config])
    |> validate_required([:slug, :name, :authority, :config])
    |> validate_inclusion(:authority, @authorities)
    |> validate_change(:config, fn :config, config ->
      if is_map(config), do: [], else: [config: "must be a map"]
    end)
    |> unique_constraint(:slug)
  end
end
