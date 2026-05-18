defmodule Argos.Arms do
  @moduledoc """
  External arm registration, sessions, and outcomes.
  """

  import Ecto.Changeset

  alias Argos.Arms.Arm
  alias Argos.Arms.Outcome
  alias Argos.Arms.Session
  alias Argos.Adaptive.OutcomeScoring
  alias Argos.Context.Packs
  alias Argos.Memory.Events
  alias Argos.Repo

  def ensure_arm(slug, attrs \\ %{}) when is_binary(slug) do
    defaults = default_arm_attrs(slug)

    attrs =
      defaults
      |> Map.merge(normalize_known_keys(attrs))
      |> Map.put(:slug, slug)

    case Repo.get_by(Arm, slug: slug) do
      nil -> %Arm{} |> Arm.changeset(attrs) |> Repo.insert()
      arm -> {:ok, arm}
    end
  end

  def start_session(attrs) when is_map(attrs) do
    attrs = normalize_known_keys(attrs)
    arm_slug = Map.get(attrs, :arm) || "codex_cli"
    author = Map.get(attrs, :author) || "operator"

    with {:ok, _arm} <- ensure_arm(arm_slug),
         %Argos.Context.ContextPack{} = pack <-
           Packs.get_pack!(Map.fetch!(attrs, :context_pack_id)) do
      session_attrs =
        attrs
        |> Map.take([:arm, :project, :task, :context_pack_id])
        |> Map.put_new(:arm, arm_slug)
        |> Map.put(:started_at, DateTime.utc_now())
        |> Map.put(:status, "active")

      case %Session{} |> Session.changeset(session_attrs) |> Repo.insert() do
        {:ok, session} ->
          Events.append_event(%{
            kind: "codex_session_started",
            canon: pack.canon,
            source: arm_slug,
            payload: %{
              "arm_session_id" => session.id,
              "context_pack_id" => pack.id,
              "context_pack_hash" => pack.hash,
              "project" => session.project,
              "task" => session.task
            },
            author: author
          })

          {:ok, session}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  rescue
    Ecto.NoResultsError -> {:error, :context_pack_not_found}
    KeyError -> {:error, :context_pack_id_required}
  end

  def end_session(attrs) when is_map(attrs) do
    attrs = normalize_known_keys(attrs)
    session_id = Map.get(attrs, :arm_session_id) || Map.get(attrs, :id)
    author = Map.get(attrs, :author) || "operator"
    status = Map.get(attrs, :status) || "ended"

    with %Session{} = session <- Repo.get(Session, session_id),
         pack <- Packs.get_pack!(session.context_pack_id),
         {:ok, session} <-
           session
           |> Session.end_changeset(%{status: status, ended_at: DateTime.utc_now()})
           |> Repo.update() do
      Events.append_event(%{
        kind: "codex_session_ended",
        canon: pack.canon,
        source: session.arm,
        payload: %{
          "arm_session_id" => session.id,
          "context_pack_id" => pack.id,
          "status" => session.status,
          "summary" => Map.get(attrs, :summary),
          "metrics" => Map.get(attrs, :metrics) || %{},
          "artifacts" => Map.get(attrs, :artifacts) || %{}
        },
        author: author
      })

      {:ok, session}
    else
      nil -> {:error, :session_not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_outcome(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_known_keys()
      |> Map.put_new(:captured_at, DateTime.utc_now())
      |> Map.put_new(:metrics, %{})
      |> Map.put_new(:artifacts, %{})

    with %Session{} = session <- Repo.get(Session, Map.get(attrs, :arm_session_id)),
         true <- session.context_pack_id == Map.get(attrs, :context_pack_id),
         pack <- Packs.get_pack!(session.context_pack_id),
         {:ok, outcome} <- %Outcome{} |> Outcome.changeset(attrs) |> Repo.insert(),
         {:ok, event} <-
           Events.append_event(%{
             kind: "codex_outcome",
             canon: pack.canon,
             source: session.arm,
             payload: %{
               "outcome_id" => outcome.id,
               "arm_session_id" => session.id,
               "context_pack_id" => pack.id,
               "result" => outcome.result,
               "summary" => outcome.summary,
               "metrics" => outcome.metrics,
               "artifacts" => outcome.artifacts
             },
             author: Map.get(attrs, :author) || "operator"
           }),
         {:ok, outcome} <- outcome |> change(event_id: event.id) |> Repo.update(),
         {:ok, _score} <- OutcomeScoring.score_outcome(outcome) do
      {:ok, outcome}
    else
      nil -> {:error, :session_not_found}
      false -> {:error, :context_pack_mismatch}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def get_session!(id), do: Repo.get!(Session, id)
  def get_outcome!(id), do: Repo.get!(Outcome, id)

  defp default_arm_attrs("codex_cli") do
    %{name: "Codex CLI", authority: "write_repo", config: %{}}
  end

  defp default_arm_attrs(slug) do
    %{name: slug, authority: "suggest_only", config: %{}}
  end

  defp normalize_known_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      pair -> pair
    end)
  end

  defp known_key("slug"), do: :slug
  defp known_key("name"), do: :name
  defp known_key("authority"), do: :authority
  defp known_key("config"), do: :config
  defp known_key("arm"), do: :arm
  defp known_key("project"), do: :project
  defp known_key("task"), do: :task
  defp known_key("context_pack_id"), do: :context_pack_id
  defp known_key("arm_session_id"), do: :arm_session_id
  defp known_key("event_id"), do: :event_id
  defp known_key("result"), do: :result
  defp known_key("summary"), do: :summary
  defp known_key("metrics"), do: :metrics
  defp known_key("artifacts"), do: :artifacts
  defp known_key("captured_at"), do: :captured_at
  defp known_key("status"), do: :status
  defp known_key("author"), do: :author
  defp known_key("id"), do: :id
  defp known_key(key), do: key
end
