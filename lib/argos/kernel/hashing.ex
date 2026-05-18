defmodule Argos.Kernel.Hashing do
  @moduledoc """
  Deterministic hashing for ARGOS memory records.

  Hashes are produced from canonical JSON with sorted object keys so equivalent
  maps always produce the same SHA-256 digest.
  """

  @event_fields ~w(author canon kind occurred_at payload prev_hash source)

  def canonical_json(term), do: encode_canonical(term)

  def sha256(term) do
    term
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def event_hash(event) do
    event
    |> event_hash_input()
    |> sha256()
  end

  def event_hash_input(event) do
    Map.new(@event_fields, fn field ->
      {field, event_value(event, field)}
    end)
  end

  defp event_value(event, "occurred_at") do
    event
    |> event_value(:occurred_at)
    |> normalize_timestamp()
  end

  defp event_value(event, field) when is_binary(field) do
    event_value(event, String.to_existing_atom(field))
  end

  defp event_value(event, field) when is_atom(field) do
    cond do
      is_map(event) && Map.has_key?(event, field) ->
        Map.get(event, field)

      is_map(event) && Map.has_key?(event, Atom.to_string(field)) ->
        Map.get(event, Atom.to_string(field))

      true ->
        nil
    end
  end

  defp normalize_timestamp(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp normalize_timestamp(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp normalize_timestamp(value), do: value

  defp encode_canonical(%DateTime{} = datetime),
    do: datetime |> DateTime.to_iso8601() |> Jason.encode!()

  defp encode_canonical(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
    |> Jason.encode!()
  end

  defp encode_canonical(%Date{} = date), do: date |> Date.to_iso8601() |> Jason.encode!()
  defp encode_canonical(%Time{} = time), do: time |> Time.to_iso8601() |> Jason.encode!()

  defp encode_canonical(%{} = map) do
    encoded =
      map
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map_join(",", fn {key, value} ->
        Jason.encode!(key) <> ":" <> encode_canonical(value)
      end)

    "{" <> encoded <> "}"
  end

  defp encode_canonical(list) when is_list(list) do
    "[" <> Enum.map_join(list, ",", &encode_canonical/1) <> "]"
  end

  defp encode_canonical(value) when is_atom(value) and value not in [true, false, nil] do
    value |> Atom.to_string() |> Jason.encode!()
  end

  defp encode_canonical(value), do: Jason.encode!(value)
end
