defmodule ArgosWeb.PageController do
  use ArgosWeb, :controller

  alias Argos.Adaptive.OutcomeScoring
  alias Argos.Approvals
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.AutonomousMutations
  alias Argos.Memory.Events

  def home(conn, _params) do
    render(conn, :home,
      event_count: length(Events.list_events()),
      pending_approval_count: length(Approvals.list_approvals(status: "pending")),
      outcome_stats: OutcomeScoring.stats(),
      proposal_stats: Proposals.stats(),
      recent_autonomous_mutations: AutonomousMutations.list_recent(5)
    )
  end
end
