defmodule Argos.ApprovalsTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
  alias Argos.Intelligence.Proposals
  alias Argos.Memory.Canons

  test "approve requires an operator decision author" do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})

    assert {:error, changeset} = Approvals.approve(approval.id, %{})
    assert "is required" in errors_on(changeset).decided_by
  end

  test "already decided approvals cannot be decided again" do
    {:ok, approval} = Canons.draft_canon("operator", %{state: %{"version" => 1}})
    assert {:ok, _approval, _canon} = Approvals.approve(approval.id, %{decided_by: "operator"})

    assert {:error, :already_decided} = Approvals.reject(approval.id, %{decided_by: "operator"})
  end

  test "proposal review approval marks proposal reviewed" do
    {:ok, proposal} = proposal_fixture("review me")

    assert {:ok, _approval, nil} =
             Approvals.approve(proposal.approval_id, %{decided_by: "operator"})

    assert Proposals.get_proposal!(proposal.id).status == "reviewed"
  end

  test "proposal review rejection marks proposal dismissed" do
    {:ok, proposal} = proposal_fixture("dismiss me")

    assert {:ok, _approval, nil} =
             Approvals.reject(proposal.approval_id, %{decided_by: "operator"})

    assert Proposals.get_proposal!(proposal.id).status == "dismissed"
  end

  defp proposal_fixture(title) do
    Proposals.create_proposal(%{
      "type" => "canon_update",
      "canon" => "operator",
      "title" => title,
      "summary" => "operator review",
      "evidence" => %{"source" => "test"},
      "proposed_action" => %{
        "kind" => "canon_update",
        "body" => %{"name" => title}
      },
      "risk_level" => "medium",
      "detector_version" => "test"
    })
  end
end
