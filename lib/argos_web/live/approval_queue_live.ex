defmodule ArgosWeb.ApprovalQueueLive do
  use ArgosWeb, :live_view

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals

  def mount(_params, _session, socket) do
    {:ok, assign_approvals(socket)}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    Approvals.approve(id, %{"decided_by" => "operator"})
    {:noreply, assign_approvals(socket)}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    Approvals.reject(id, %{"decided_by" => "operator"})
    {:noreply, assign_approvals(socket)}
  end

  def render(assigns) do
    ~H"""
    <main class="argos-shell min-h-screen px-6 py-8 text-base-content">
      <section class="mx-auto flex max-w-6xl flex-col gap-6">
        <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-wide text-primary">ARGOS</p>
            <h1 class="mt-2 text-3xl font-semibold">Approval queue</h1>
            <p class="mt-2 max-w-2xl text-sm text-base-content/70">
              Review MCP-submitted proposals and canon commits before they become durable state.
            </p>
          </div>
          <a href={~p"/"} class="btn btn-sm btn-outline">Dashboard</a>
        </div>

        <div class="grid gap-4 md:grid-cols-3">
          <div class="rounded-lg border border-base-300 p-4">
            <p class="text-sm text-base-content/60">Pending</p>
            <p class="mt-2 text-2xl font-semibold">{length(@approvals)}</p>
          </div>
          <div class="rounded-lg border border-base-300 p-4">
            <p class="text-sm text-base-content/60">Gate</p>
            <p class="mt-2 text-lg font-semibold">operator decision</p>
          </div>
          <div class="rounded-lg border border-base-300 p-4">
            <p class="text-sm text-base-content/60">Effect</p>
            <p class="mt-2 text-lg font-semibold">approve or dismiss</p>
          </div>
        </div>

        <div
          :if={Enum.empty?(@approvals)}
          class="rounded-lg border border-base-300 p-8 text-base-content/60"
        >
          No pending approvals.
        </div>

        <article
          :for={item <- @approvals}
          id={"approval-#{item.id}"}
          class="argos-panel rounded-lg p-5"
        >
          <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <span class={risk_badge_class(item.risk_level)}>{item.risk_level}</span>
                <span class="badge badge-outline">{item.action}</span>
                <span class="badge badge-outline">{item.status}</span>
              </div>
              <h2 class="mt-3 text-xl font-semibold">{item.title}</h2>
              <p class="mt-2 max-w-3xl text-sm text-base-content/70">{item.summary}</p>
            </div>

            <div class="flex shrink-0 gap-2">
              <button
                type="button"
                class="btn btn-sm btn-primary"
                phx-click="approve"
                phx-value-id={item.id}
              >
                Approve
              </button>
              <button
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="reject"
                phx-value-id={item.id}
              >
                Reject
              </button>
            </div>
          </div>

          <div class="mt-5 h-1 w-full rounded-full argos-flame-rule"></div>

          <section class="mt-5 rounded-lg border argos-ember-border bg-base-200/70 p-5">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-primary">
                  {item.practice} / {item.target}
                </p>
                <h3 class="mt-2 text-2xl font-semibold">{item.entry_name}</h3>
              </div>
              <div class="flex flex-wrap gap-2">
                <span class="badge badge-primary">{item.proposal_action}</span>
                <span class="badge badge-outline">{item.confidence}</span>
              </div>
            </div>

            <div class="mt-5 grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
              <div class="rounded-lg border border-base-300 bg-base-100/80 p-4">
                <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                  Observation
                </h4>
                <p class="mt-3 text-sm leading-6">{item.observation}</p>
              </div>

              <div class="rounded-lg border border-primary/30 bg-primary/10 p-4">
                <h4 class="text-sm font-semibold uppercase tracking-wide text-primary">
                  Binding
                </h4>
                <p class="mt-3 text-sm leading-6">{item.binding}</p>
              </div>
            </div>

            <div class="mt-4 rounded-lg border border-base-300 bg-base-100/80 p-4">
              <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Provenance
              </h4>
              <p class="mt-3 text-sm leading-6 text-base-content/80">{item.provenance}</p>
            </div>

            <div class="mt-4">
              <div class="flex items-center justify-between gap-4">
                <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                  Initial failure modes
                </h4>
                <span class="text-xs text-base-content/50">{length(item.failure_modes)} checks</span>
              </div>
              <div class="mt-3 grid gap-3 lg:grid-cols-2">
                <div
                  :for={failure <- item.failure_modes}
                  class="rounded-lg border border-base-300 bg-base-100/80 p-4"
                >
                  <p class="text-sm font-semibold">{failure["name"] || failure[:name]}</p>
                  <p class="mt-2 text-sm leading-6 text-base-content/70">
                    {failure["trigger"] || failure[:trigger]}
                  </p>
                </div>
              </div>
            </div>
          </section>

          <div class="mt-5 grid gap-4 lg:grid-cols-2">
            <section class="rounded-lg bg-base-200 p-4">
              <h3 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Request
              </h3>
              <dl class="mt-3 grid gap-2 text-sm">
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Approval ID</dt>
                  <dd class="break-all sm:col-span-2">{item.id}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Subject</dt>
                  <dd class="break-all sm:col-span-2">{item.subject}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Inserted</dt>
                  <dd class="sm:col-span-2">{item.inserted_at}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Reason</dt>
                  <dd class="sm:col-span-2">{item.reason}</dd>
                </div>
              </dl>
            </section>

            <section class="rounded-lg bg-base-200 p-4">
              <h3 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Proposal
              </h3>
              <dl class="mt-3 grid gap-2 text-sm">
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Name</dt>
                  <dd class="break-all sm:col-span-2">{item.entry_name}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Canon</dt>
                  <dd class="sm:col-span-2">{item.canon}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Detector</dt>
                  <dd class="sm:col-span-2">{item.detector_version}</dd>
                </div>
                <div class="grid gap-1 sm:grid-cols-3">
                  <dt class="text-base-content/60">Dedupe</dt>
                  <dd class="break-all sm:col-span-2">{item.dedupe_hash}</dd>
                </div>
              </dl>
            </section>
          </div>

          <section class="mt-4 rounded-lg border border-primary/30 bg-base-200/80 p-4">
            <h3 class="text-sm font-semibold uppercase tracking-wide text-primary">
              Where it lives after approval
            </h3>
            <div class="mt-3 grid gap-3 lg:grid-cols-2">
              <div class="rounded-lg border border-base-300 bg-base-100/80 p-3">
                <p class="text-sm font-semibold">ARGOS backend</p>
                <p class="mt-1 text-sm leading-6 text-base-content/70">{item.storage_effect}</p>
              </div>
              <div class="rounded-lg border border-base-300 bg-base-100/80 p-3">
                <p class="text-sm font-semibold">External target</p>
                <p class="mt-1 text-sm leading-6 text-base-content/70">{item.external_effect}</p>
              </div>
            </div>
          </section>

          <details class="mt-4 rounded-lg border border-base-300 bg-base-200 p-4">
            <summary class="cursor-pointer text-sm font-semibold">Raw proposed action JSON</summary>
            <pre class="mt-3 overflow-x-auto rounded bg-neutral p-4 text-xs text-neutral-content"><code>{item.proposed_action_json}</code></pre>
          </details>
        </article>

        <section class="argos-panel rounded-lg p-5">
          <div class="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-primary">Backend</p>
              <h2 class="mt-1 text-2xl font-semibold">Recent decisions</h2>
            </div>
            <p class="max-w-2xl text-sm text-base-content/70">
              Approved proposal reviews are stored in ARGOS. External targets such as Constellation
              need a sync adapter before their UI updates.
            </p>
          </div>

          <div
            :if={Enum.empty?(@recent_decisions)}
            class="mt-5 rounded-lg border border-base-300 p-6 text-sm text-base-content/60"
          >
            No recent decisions.
          </div>

          <div class="mt-5 grid gap-3">
            <article
              :for={item <- @recent_decisions}
              id={"decision-#{item.id}"}
              class="rounded-lg border border-base-300 bg-base-200/70 p-4"
            >
              <div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                <div>
                  <div class="flex flex-wrap items-center gap-2">
                    <span class={decision_badge_class(item.status)}>{item.status}</span>
                    <span class="badge badge-outline">{item.action}</span>
                    <span class="badge badge-outline">{item.target}</span>
                  </div>
                  <h3 class="mt-3 text-lg font-semibold">{item.entry_name}</h3>
                  <p class="mt-1 text-sm text-base-content/70">{item.storage_effect}</p>
                </div>
                <div class="rounded-lg border border-base-300 bg-base-100/80 p-3 text-sm md:max-w-md">
                  <p class="font-semibold">External sync</p>
                  <p class="mt-1 text-base-content/70">{item.external_effect}</p>
                </div>
              </div>
            </article>
          </div>
        </section>
      </section>
    </main>
    """
  end

  defp assign_approvals(socket) do
    approvals =
      Approvals.list_approvals(status: "pending")
      |> Enum.map(&approval_view/1)

    recent_decisions =
      Approvals.list_approvals()
      |> Enum.reject(&(&1.status == "pending"))
      |> Enum.map(&approval_view/1)
      |> Enum.reject(&test_artifact?/1)
      |> Enum.take(8)

    socket
    |> assign(:approvals, approvals)
    |> assign(:recent_decisions, recent_decisions)
  end

  defp approval_view(approval) do
    proposal = load_subject_proposal(approval)
    body = body_from(approval, proposal)

    %{
      id: approval.id,
      action: approval.action,
      risk_level: approval.risk_level,
      status: approval.status,
      subject: "#{approval.subject_type}:#{approval.subject_id}",
      inserted_at: Calendar.strftime(approval.inserted_at, "%Y-%m-%d %H:%M:%S UTC"),
      reason: approval.reason || "-",
      title:
        proposal_value(proposal, :title) || get_in(approval.proposal, ["title"]) ||
          approval.action,
      summary: proposal_value(proposal, :summary) || approval.reason || "-",
      canon: proposal_value(proposal, :canon) || Map.get(body, "canon") || "operator",
      detector_version: proposal_value(proposal, :detector_version) || "-",
      dedupe_hash: proposal_value(proposal, :dedupe_hash) || "-",
      entry_name: Map.get(body, "name") || Map.get(body, "entry_name") || "-",
      proposal_action: Map.get(body, "action") || "-",
      binding: Map.get(body, "binding") || "-",
      confidence: Map.get(body, "confidence") || "-",
      failure_modes: failure_modes_from(body),
      observation: Map.get(body, "observation") || "-",
      practice: Map.get(body, "practice") || "-",
      provenance: Map.get(body, "provenance") || "-",
      target: Map.get(body, "target") || "-",
      storage_effect: storage_effect(approval),
      external_effect: external_effect(Map.get(body, "target")),
      proposed_action_json: encode_pretty(proposed_action_from(approval, proposal))
    }
  end

  defp load_subject_proposal(%{subject_type: "proposal", subject_id: subject_id})
       when is_binary(subject_id) do
    try do
      Proposals.get_proposal!(subject_id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

  defp load_subject_proposal(_approval), do: nil

  defp proposal_value(nil, _field), do: nil
  defp proposal_value(proposal, field), do: Map.get(proposal, field)

  defp proposed_action_from(_approval, %{proposed_action: proposed_action})
       when is_map(proposed_action) do
    proposed_action
  end

  defp proposed_action_from(approval, _proposal) do
    get_in(approval.proposal, ["proposed_action"]) || %{}
  end

  defp body_from(approval, proposal) do
    case proposed_action_from(approval, proposal) do
      %{"body" => body} when is_map(body) -> body
      %{:body => body} when is_map(body) -> body
      _other -> %{}
    end
  end

  defp encode_pretty(value) do
    Jason.encode!(value || %{}, pretty: true)
  end

  defp failure_modes_from(%{"initialFailureModes" => failure_modes})
       when is_list(failure_modes) do
    failure_modes
  end

  defp failure_modes_from(%{:initialFailureModes => failure_modes}) when is_list(failure_modes) do
    failure_modes
  end

  defp failure_modes_from(_body), do: []

  defp storage_effect(%{action: "proposal_review", status: "pending"}) do
    "On approve: ARGOS sets approval.status=approved, proposal.status=reviewed, and appends an approval_decided event."
  end

  defp storage_effect(%{action: "proposal_review", status: "approved"}) do
    "Stored in ARGOS Postgres: approvals.status=approved, proposal_queue.status=reviewed, and an approval_decided event was appended."
  end

  defp storage_effect(%{action: "proposal_review", status: "rejected"}) do
    "Stored in ARGOS Postgres: approvals.status=rejected, proposal_queue.status=dismissed, and an approval_decided event was appended."
  end

  defp storage_effect(%{action: "canon_commit", status: "approved"}) do
    "Stored in ARGOS Postgres and committed as an immutable canon version."
  end

  defp storage_effect(%{action: "canon_commit", status: "pending"}) do
    "On approve: ARGOS commits an immutable canon version and appends canon/approval events."
  end

  defp storage_effect(_approval), do: "Stored in ARGOS Postgres as an approval decision."

  defp external_effect("constellation") do
    "Constellation sync is not wired yet, so approving here does not call constellation_add or update the Constellation UI."
  end

  defp external_effect("-"), do: "No external target declared."
  defp external_effect(nil), do: "No external target declared."

  defp external_effect(target) do
    "External target #{target} is declared, but no sync adapter is configured."
  end

  defp test_artifact?(%{entry_name: "playwright-greenlight-" <> _rest}), do: true
  defp test_artifact?(%{entry_name: "screenshot-routing-" <> _rest}), do: true
  defp test_artifact?(_item), do: false

  defp risk_badge_class("critical"), do: "badge badge-error"
  defp risk_badge_class("high"), do: "badge badge-error"
  defp risk_badge_class("medium"), do: "badge badge-warning"
  defp risk_badge_class(_risk), do: "badge badge-success"

  defp decision_badge_class("approved"), do: "badge badge-success"
  defp decision_badge_class("rejected"), do: "badge badge-error"
  defp decision_badge_class(_status), do: "badge badge-outline"
end
