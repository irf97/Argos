defmodule Argos.Memory.Event do
  @moduledoc """
  Append-only memory event.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @allowed_kinds ~w(
    artifact_attached
    approval_created
    approval_decided
    autonomous_mutation_applied
    autonomous_mutation_rolled_back
    canon_commit
    canon_draft
    codex_outcome
    codex_session_ended
    codex_session_started
    context_pack_compiled
    crawl_ingested
    decision_recorded
    manual_note
    voice_note
  )

  @required_fields ~w(kind canon source payload author occurred_at)a
  @append_fields [:prev_hash | @required_fields]
  @insert_fields [:hash | @append_fields]
  @hash_format ~r/\A[0-9a-f]{64}\z/

  schema "events" do
    field :kind, :string
    field :canon, :string
    field :source, :string
    field :payload, :map
    field :prev_hash, :string
    field :hash, :string
    field :author, :string
    field :occurred_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def allowed_kinds, do: @allowed_kinds

  def append_changeset(event, attrs) do
    event
    |> cast(attrs, @append_fields)
    |> validate_required(@required_fields)
    |> validate_common()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, @insert_fields)
    |> validate_required([:hash | @required_fields])
    |> validate_common()
    |> validate_format(:hash, @hash_format)
  end

  defp validate_common(changeset) do
    changeset
    |> validate_inclusion(:kind, @allowed_kinds)
    |> validate_exclusion(:kind, ["misc"], message: "must be explicit")
    |> validate_length(:canon, min: 1)
    |> validate_length(:source, min: 1)
    |> validate_length(:author, min: 1)
    |> validate_format(:prev_hash, @hash_format)
    |> validate_change(:payload, fn :payload, payload ->
      if is_map(payload), do: [], else: [payload: "must be a map"]
    end)
  end
end
