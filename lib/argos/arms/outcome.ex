defmodule Argos.Arms.Outcome do
  @moduledoc """
  Captured outcome for an external arm session.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Arms.Session
  alias Argos.Context.ContextPack
  alias Argos.Memory.Event

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outcomes" do
    field :result, :string
    field :summary, :string
    field :metrics, :map, default: %{}
    field :artifacts, :map, default: %{}
    field :captured_at, :utc_datetime_usec

    belongs_to :arm_session, Session
    belongs_to :context_pack, ContextPack
    belongs_to :event, Event

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [
      :arm_session_id,
      :context_pack_id,
      :event_id,
      :result,
      :summary,
      :metrics,
      :artifacts,
      :captured_at
    ])
    |> validate_required([:arm_session_id, :context_pack_id, :result, :summary, :captured_at])
    |> validate_inclusion(:result, ["success", "partial", "fail", "blocked"])
    |> validate_change(:metrics, &validate_map/2)
    |> validate_change(:artifacts, &validate_map/2)
    |> foreign_key_constraint(:arm_session_id)
    |> foreign_key_constraint(:context_pack_id)
    |> foreign_key_constraint(:event_id)
  end

  defp validate_map(field, value) do
    if is_map(value), do: [], else: [{field, "must be a map"}]
  end
end
