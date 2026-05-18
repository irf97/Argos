defmodule ArgosWeb.ApprovalQueueLive do
  use ArgosWeb, :live_view

  alias Argos.Approvals

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
        <div>
          <p class="text-sm font-semibold uppercase tracking-wide text-base-content/60">ARGOS</p>
          <h1 class="mt-2 text-3xl font-semibold">Approval queue</h1>
        </div>

        <div class="overflow-x-auto rounded-lg border border-base-300">
          <table class="table">
            <thead>
              <tr>
                <th>Action</th>
                <th>Subject</th>
                <th>Risk</th>
                <th>Status</th>
                <th>Reason</th>
                <th class="text-right">Decision</th>
              </tr>
            </thead>
            <tbody>
              <tr :if={Enum.empty?(@approvals)}>
                <td colspan="6" class="text-base-content/60">No pending approvals.</td>
              </tr>
              <tr :for={approval <- @approvals} id={"approval-#{approval.id}"}>
                <td>{approval.action}</td>
                <td>{approval.subject_type}</td>
                <td>{approval.risk_level}</td>
                <td>{approval.status}</td>
                <td>{approval.reason || "-"}</td>
                <td class="flex justify-end gap-2">
                  <button
                    type="button"
                    class="btn btn-sm btn-primary"
                    phx-click="approve"
                    phx-value-id={approval.id}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    class="btn btn-sm btn-ghost"
                    phx-click="reject"
                    phx-value-id={approval.id}
                  >
                    Reject
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>
    """
  end

  defp assign_approvals(socket) do
    assign(socket, :approvals, Approvals.list_approvals(status: "pending"))
  end
end
