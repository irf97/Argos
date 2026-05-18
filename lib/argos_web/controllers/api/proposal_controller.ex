defmodule ArgosWeb.Api.ProposalController do
  use ArgosWeb, :controller

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals

  def index(conn, params) do
    opts =
      case Map.get(params, "status") do
        nil -> []
        status -> [status: status]
      end

    proposals = Proposals.list_proposals(opts)
    json(conn, %{proposals: Enum.map(proposals, &proposal_json/1)})
  end

  def detect(conn, params) do
    results = Proposals.detect(params)

    errors =
      results
      |> Enum.filter(&match?({:error, _reason}, &1))
      |> Enum.map(fn {:error, reason} -> inspect(reason) end)

    proposals =
      results
      |> Enum.filter(&match?({:ok, _proposal}, &1))
      |> Enum.map(fn {:ok, proposal} -> proposal_json(proposal) end)

    status = if errors == [], do: :created, else: :unprocessable_entity

    conn
    |> put_status(status)
    |> json(%{proposals: proposals, errors: errors})
  end

  defp proposal_json(proposal) do
    approval = if proposal.approval_id, do: Approvals.get_approval!(proposal.approval_id)

    %{
      id: proposal.id,
      type: proposal.type,
      canon: proposal.canon,
      canon_version: proposal.canon_version,
      status: proposal.status,
      title: proposal.title,
      summary: proposal.summary,
      evidence: proposal.evidence,
      proposed_action: proposal.proposed_action,
      risk_level: proposal.risk_level,
      approval_id: proposal.approval_id,
      approval_status: if(approval, do: approval.status),
      detector_version: proposal.detector_version,
      dedupe_hash: proposal.dedupe_hash
    }
  end
end
