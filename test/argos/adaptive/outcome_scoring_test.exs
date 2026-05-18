defmodule Argos.Adaptive.OutcomeScoringTest do
  use Argos.DataCase, async: true

  alias Argos.Adaptive.OutcomeScoring
  alias Argos.Approvals
  alias Argos.Arms
  alias Argos.Context.Packs
  alias Argos.Memory.Canons

  test "scores outcomes deterministically from explicit rules" do
    {:ok, outcome} = create_outcome(result: "success", metrics: %{"test_status" => "pass"})

    score = OutcomeScoring.get_score_for_outcome(outcome.id)

    assert score.score == 100
    assert score.grade == "excellent"
    assert score.rules_applied["result"] == "success"
    assert score.policy_metadata["autonomous_policy_update"] == false
  end

  test "canon-specific explicit rules are honored without mutating canon" do
    {:ok, approval} =
      Canons.draft_canon("operator", %{
        state: %{
          "outcome_scoring" => %{
            "result_scores" => %{"fail" => 7}
          }
        }
      })

    {:ok, _approval, canon} = Approvals.approve(approval.id, %{decided_by: "operator"})
    canon_hash = canon.hash

    {:ok, outcome} = create_outcome(result: "fail", metrics: %{"test_status" => "pass"})

    score = OutcomeScoring.get_score_for_outcome(outcome.id)

    assert score.score == 7
    assert score.grade == "poor"
    assert score.policy_metadata["canon_hash"] == canon_hash
    assert Canons.get_canon("operator").hash == canon_hash
  end

  test "score links to outcome and context pack" do
    {:ok, outcome} = create_outcome(result: "partial", metrics: %{"test_status" => "not_run"})
    score = OutcomeScoring.get_score_for_outcome(outcome.id)

    assert score.outcome_id == outcome.id
    assert score.context_pack_id == outcome.context_pack_id
    assert score.score == 60
  end

  test "stats summarize scores by canon" do
    {:ok, _outcome} = create_outcome(result: "fail", metrics: %{"test_status" => "fail"})

    stats = OutcomeScoring.stats()

    assert stats.scored_outcomes_count == 1
    assert stats.average_score_by_canon["operator"] == 5.0
    assert length(stats.latest_low_scores) == 1
  end

  defp create_outcome(opts) do
    result = Keyword.fetch!(opts, :result)
    metrics = Keyword.get(opts, :metrics, %{})

    {:ok, pack} = Packs.create_pack(%{canon: "operator", task: "score outcome #{result}"})

    {:ok, session} =
      Arms.start_session(%{
        arm: "codex_cli",
        project: "argos",
        task: pack.task,
        context_pack_id: pack.id
      })

    Arms.create_outcome(%{
      arm_session_id: session.id,
      context_pack_id: pack.id,
      result: result,
      summary: "Outcome #{result}",
      metrics: metrics,
      artifacts: %{}
    })
  end
end
