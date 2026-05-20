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
    <main class="min-h-screen bg-base-100 px-6 py-8 text-base-content">
      <section class="mx-auto flex max-w-6xl flex-col gap-6">
        <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-wide text-base-content/60">ARGOS</p>
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
          class="rounded-lg border border-base-300 bg-base-100 p-5"
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

          <details class="mt-4 rounded-lg border border-base-300 bg-base-200 p-4">
            <summary class="cursor-pointer text-sm font-semibold">Proposed action JSON</summary>
            <pre class="mt-3 overflow-x-auto rounded bg-neutral p-4 text-xs text-neutral-content"><code>{item.proposed_action_json}</code></pre>
          </details>
        </article>
      </section>
    </main>
    """
  end

  defp assign_approvals(socket) do
    approvals =
      Approvals.list_approvals(status: "pending")
      |> Enum.map(&approval_view/1)

    assign(socket, :approvals, approvals)
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

  defp risk_badge_class("critical"), do: "badge badge-error"
  defp risk_badge_class("high"), do: "badge badge-error"
  defp risk_badge_class("medium"), do: "badge badge-warning"
  defp risk_badge_class(_risk), do: "badge badge-success"
end
