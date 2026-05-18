defmodule Argos.Ingest.CrawlJob do
  @moduledoc """
  Local-first crawl or prompt packet persisted before any normalized ingest.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Argos.Memory.Event

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(kind status seek prompt raw_input raw_output normalized_records requested_at)a
  @optional_fields ~w(event_id error completed_at)a

  schema "crawl_jobs" do
    field :kind, :string, default: "crawl"
    field :status, :string, default: "queued"
    field :seek, :map, default: %{}
    field :prompt, :string
    field :raw_input, :map, default: %{}
    field :raw_output, :map, default: %{}
    field :normalized_records, :map, default: %{}
    field :error, :string
    field :requested_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :event, Event

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(crawl_job, attrs) do
    crawl_job
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:kind, ["crawl", "crawl_and_ingest"])
    |> validate_inclusion(:status, ["queued", "completed", "failed"])
    |> validate_change(:seek, &validate_map/2)
    |> validate_change(:raw_input, &validate_map/2)
    |> validate_change(:raw_output, &validate_map/2)
    |> validate_change(:normalized_records, &validate_map/2)
    |> foreign_key_constraint(:event_id)
  end

  defp validate_map(field, value) do
    if is_map(value), do: [], else: [{field, "must be a map"}]
  end
end
