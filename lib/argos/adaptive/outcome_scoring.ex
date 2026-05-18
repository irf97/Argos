defmodule Argos.Adaptive.OutcomeScoring do
  @moduledoc """
  Deterministic outcome scoring stub.

  Scores are recorded for inspection only. They never update canon, policy, or
  execution authority.
  """

  import Ecto.Query

  alias Argos.Adaptive.OutcomeScore
  alias Argos.Arms.Outcome
  alias Argos.Context.Packs
  alias Argos.Memory.Canons
  alias Argos.Repo

  @rule_version "outcome_scoring_v1"
  @default_rules %{
    "result_scores" => %{
      "success" => 100,
      "partial" => 65,
      "blocked" => 40,
      "fail" => 20
    },
    "test_status_adjustments" => %{
      "pass" => 0,
      "not_run" => -5,
      "fail" => -15
    }
  }

  def score_outcome(%Outcome{} = outcome) do
    pack = Packs.get_pack!(outcome.context_pack_id)
    canon = Canons.get_canon(pack.canon)
    rules = rules_for_canon(canon)

    result_score = get_in(rules, ["result_scores", outcome.result]) || 0
    test_status = get_in(outcome.metrics || %{}, ["test_status"])
    adjustment = get_in(rules, ["test_status_adjustments", test_status]) || 0
    score = clamp(result_score + adjustment)

    attrs = %{
      outcome_id: outcome.id,
      context_pack_id: outcome.context_pack_id,
      canon: pack.canon,
      score: score,
      grade: grade(score),
      rule_version: @rule_version,
      rules_applied: %{
        "result" => outcome.result,
        "result_score" => result_score,
        "test_status" => test_status,
        "test_status_adjustment" => adjustment,
        "rules" => rules
      },
      explanation:
        "Score #{score} from result=#{outcome.result} and test_status=#{test_status || "unknown"}.",
      policy_metadata: %{
        "autonomous_policy_update" => false,
        "canon_hash" => if(canon, do: canon.hash)
      },
      scored_at: DateTime.utc_now()
    }

    %OutcomeScore{}
    |> OutcomeScore.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace, [:score, :grade, :rules_applied, :explanation, :policy_metadata, :scored_at]},
      conflict_target: :outcome_id
    )
  end

  def get_score_for_outcome(outcome_id) do
    Repo.get_by(OutcomeScore, outcome_id: outcome_id)
  end

  def stats do
    scores = Repo.all(from score in OutcomeScore, order_by: [desc: score.scored_at])
    count = length(scores)

    average_by_canon =
      scores
      |> Enum.group_by(& &1.canon)
      |> Map.new(fn {canon, canon_scores} ->
        average =
          canon_scores
          |> Enum.map(& &1.score)
          |> then(&(Enum.sum(&1) / max(length(&1), 1)))
          |> Float.round(1)

        {canon, average}
      end)

    %{
      scored_outcomes_count: count,
      average_score_by_canon: average_by_canon,
      latest_low_scores: Enum.filter(scores, &(&1.score < 50)) |> Enum.take(5)
    }
  end

  defp rules_for_canon(nil), do: @default_rules

  defp rules_for_canon(canon) do
    canon_rules = get_in(canon.state || %{}, ["outcome_scoring"]) || %{}

    @default_rules
    |> deep_merge(canon_rules)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(_left, right), do: right

  defp clamp(score), do: score |> max(0) |> min(100)

  defp grade(score) when score >= 90, do: "excellent"
  defp grade(score) when score >= 70, do: "good"
  defp grade(score) when score >= 50, do: "partial"
  defp grade(_score), do: "poor"
end
