defmodule ArgosWeb.Api.OutcomeController do
  use ArgosWeb, :controller

  alias Argos.Adaptive.OutcomeScoring
  alias Argos.Arms

  def create(conn, params) do
    case Arms.create_outcome(params) do
      {:ok, outcome} ->
        conn
        |> put_status(:created)
        |> json(%{outcome: outcome_json(outcome)})

      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "arm session not found"})

      {:error, :context_pack_mismatch} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "context pack does not match arm session"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  defp outcome_json(outcome) do
    %{
      id: outcome.id,
      arm_session_id: outcome.arm_session_id,
      context_pack_id: outcome.context_pack_id,
      event_id: outcome.event_id,
      result: outcome.result,
      summary: outcome.summary,
      metrics: outcome.metrics,
      artifacts: outcome.artifacts,
      captured_at: DateTime.to_iso8601(outcome.captured_at),
      score: score_json(OutcomeScoring.get_score_for_outcome(outcome.id))
    }
  end

  defp score_json(nil), do: nil

  defp score_json(score) do
    %{
      id: score.id,
      score: score.score,
      grade: score.grade,
      rule_version: score.rule_version,
      rules_applied: score.rules_applied,
      explanation: score.explanation,
      policy_metadata: score.policy_metadata,
      scored_at: DateTime.to_iso8601(score.scored_at)
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
