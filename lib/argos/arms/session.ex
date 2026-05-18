defmodule Argos.Arms.Session do
  @moduledoc """
  External arm session tied to a context pack.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Context.ContextPack

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "arm_sessions" do
    field :arm, :string
    field :project, :string
    field :task, :string
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :status, :string

    belongs_to :context_pack, ContextPack

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:arm, :project, :task, :context_pack_id, :started_at, :ended_at, :status])
    |> validate_required([:arm, :project, :task, :context_pack_id, :started_at, :status])
    |> validate_inclusion(:status, ["active", "ended", "blocked"])
    |> foreign_key_constraint(:context_pack_id)
  end

  def end_changeset(session, attrs) do
    session
    |> cast(attrs, [:ended_at, :status])
    |> validate_required([:ended_at, :status])
    |> validate_inclusion(:status, ["ended", "blocked"])
  end
end
