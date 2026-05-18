defmodule Argos.ApprovalsTest do
  use Argos.DataCase, async: true

  alias Argos.Approvals
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
end
