defmodule Argos.Memory.Events do
  @moduledoc """
  Memory event append and hash-chain validation.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Argos.Kernel.Hashing
  alias Argos.Memory.Event
  alias Argos.Repo

  def append_event(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_known_keys()
      |> Map.put_new(:occurred_at, DateTime.utc_now())

    changeset = Event.append_changeset(%Event{}, attrs)

    if changeset.valid? do
      append_valid_event(changeset)
    else
      {:error, changeset}
    end
  end

  def append_event(_attrs) do
    changeset =
      %Event{}
      |> Event.append_changeset(%{})
      |> add_error(:payload, "must be a map")

    {:error, changeset}
  end

  def list_events(opts \\ []) do
    Event
    |> maybe_filter_canon(Keyword.get(opts, :canon))
    |> maybe_filter_kind(Keyword.get(opts, :kind))
    |> order_events(Keyword.get(opts, :order, :asc))
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  def get_event(id) when is_binary(id), do: Repo.get(Event, id)

  def validate_chain(canon) when is_binary(canon) do
    with {:ok, events} <- canon_chain_events(canon) do
      validate_chain(events)
    end
  end

  def validate_chain(events) when is_list(events) do
    events
    |> Enum.reduce_while(nil, fn event, previous ->
      expected_prev_hash = if previous, do: event_field(previous, :hash)

      cond do
        event_field(event, :prev_hash) != expected_prev_hash ->
          {:halt, {:error, {:prev_hash_mismatch, event_identifier(event)}}}

        event_field(event, :hash) != Hashing.event_hash(event) ->
          {:halt, {:error, {:hash_mismatch, event_identifier(event)}}}

        true ->
          {:cont, event}
      end
    end)
    |> case do
      {:error, _reason} = error -> error
      _last_event -> :ok
    end
  end

  defp append_valid_event(changeset) do
    event = apply_changes(changeset)

    Repo.transaction(fn ->
      lock_canon(event.canon)

      expected_prev_hash =
        case latest_event_for_canon(event.canon) do
          nil -> nil
          latest_event -> latest_event.hash
        end

      requested_prev_hash = get_field(changeset, :prev_hash)

      if requested_prev_hash && requested_prev_hash != expected_prev_hash do
        changeset
        |> add_error(:prev_hash, "does not match latest event hash")
        |> then(&Repo.rollback({:error, &1}))
      end

      attrs =
        event
        |> Map.take([:kind, :canon, :source, :payload, :author, :occurred_at])
        |> Map.put(:prev_hash, expected_prev_hash)
        |> then(fn attrs -> Map.put(attrs, :hash, Hashing.event_hash(attrs)) end)

      %Event{}
      |> Event.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, event} -> event
        {:error, changeset} -> Repo.rollback({:error, changeset})
      end
    end)
    |> case do
      {:ok, event} -> {:ok, event}
      {:error, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  defp latest_event_for_canon(canon) do
    Event
    |> where([event], event.canon == ^canon)
    |> order_by([event], desc: event.inserted_at, desc: event.id)
    |> limit(1)
    |> Repo.one()
  end

  defp canon_chain_events(canon) do
    events = list_events(canon: canon)

    case events do
      [] -> {:ok, []}
      [_ | _] -> order_by_hash_chain(events)
    end
  end

  defp order_by_hash_chain(events) do
    roots = Enum.filter(events, &(event_field(&1, :prev_hash) == nil))

    with {:ok, root} <- single_root(roots, events),
         {:ok, next_by_prev_hash} <- next_by_prev_hash(events),
         {:ok, ordered} <- walk_chain(root, next_by_prev_hash, length(events)) do
      {:ok, ordered}
    end
  end

  defp single_root([root], _events), do: {:ok, root}

  defp single_root([], [event | _events]) do
    {:error, {:prev_hash_mismatch, event_identifier(event)}}
  end

  defp single_root([_root, fork | _rest], _events) do
    {:error, {:prev_hash_mismatch, event_identifier(fork)}}
  end

  defp next_by_prev_hash(events) do
    events
    |> Enum.reject(&(event_field(&1, :prev_hash) == nil))
    |> Enum.group_by(&event_field(&1, :prev_hash))
    |> Enum.reduce_while({:ok, %{}}, fn
      {_prev_hash, [event]}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, event_field(event, :prev_hash), event)}}

      {_prev_hash, [_event, fork | _rest]}, {:ok, _acc} ->
        {:halt, {:error, {:prev_hash_mismatch, event_identifier(fork)}}}
    end)
  end

  defp walk_chain(root, next_by_prev_hash, expected_count) do
    do_walk_chain(root, next_by_prev_hash, expected_count, MapSet.new(), [])
  end

  defp do_walk_chain(event, next_by_prev_hash, expected_count, seen_hashes, acc) do
    hash = event_field(event, :hash)

    cond do
      MapSet.member?(seen_hashes, hash) ->
        {:error, {:prev_hash_mismatch, event_identifier(event)}}

      length(acc) + 1 > expected_count ->
        {:error, {:prev_hash_mismatch, event_identifier(event)}}

      true ->
        seen_hashes = MapSet.put(seen_hashes, hash)
        acc = [event | acc]

        case Map.get(next_by_prev_hash, hash) do
          nil ->
            ordered = Enum.reverse(acc)

            if length(ordered) == expected_count do
              {:ok, ordered}
            else
              {:error, {:prev_hash_mismatch, missing_link_identifier(ordered, next_by_prev_hash)}}
            end

          next_event ->
            do_walk_chain(next_event, next_by_prev_hash, expected_count, seen_hashes, acc)
        end
    end
  end

  defp missing_link_identifier(ordered, next_by_prev_hash) do
    ordered_hashes =
      ordered
      |> Enum.map(&event_field(&1, :hash))
      |> MapSet.new()

    next_by_prev_hash
    |> Map.values()
    |> Enum.find(&(not MapSet.member?(ordered_hashes, event_field(&1, :hash))))
    |> event_identifier()
  end

  defp lock_canon(canon) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [canon])
  end

  defp maybe_filter_canon(query, nil), do: query

  defp maybe_filter_canon(query, canon) do
    where(query, [event], event.canon == ^canon)
  end

  defp maybe_filter_kind(query, nil), do: query

  defp maybe_filter_kind(query, kind) do
    where(query, [event], event.kind == ^kind)
  end

  defp order_events(query, :desc) do
    order_by(query, [event], desc: event.inserted_at, desc: event.id)
  end

  defp order_events(query, _order) do
    order_by(query, [event], asc: event.inserted_at, asc: event.id)
  end

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0 do
    limit(query, ^limit)
  end

  defp maybe_limit(query, _limit), do: query

  defp normalize_known_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      pair -> pair
    end)
  end

  defp known_key("kind"), do: :kind
  defp known_key("canon"), do: :canon
  defp known_key("source"), do: :source
  defp known_key("payload"), do: :payload
  defp known_key("prev_hash"), do: :prev_hash
  defp known_key("hash"), do: :hash
  defp known_key("author"), do: :author
  defp known_key("occurred_at"), do: :occurred_at
  defp known_key(key), do: key

  defp event_identifier(event), do: event_field(event, :id) || event_field(event, :hash)

  defp event_field(event, field) do
    cond do
      is_map(event) && Map.has_key?(event, field) ->
        Map.get(event, field)

      is_map(event) && Map.has_key?(event, Atom.to_string(field)) ->
        Map.get(event, Atom.to_string(field))

      true ->
        nil
    end
  end
end
