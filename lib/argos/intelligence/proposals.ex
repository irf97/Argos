defmodule Argos.Intelligence.Proposals do
  @moduledoc """
  Proposal-only intelligence queue.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Argos.Approvals
  alias Argos.Intelligence.ContradictionDetector
  alias Argos.Intelligence.GapDetector
  alias Argos.Intelligence.Proposal
  alias Argos.Kernel.Hashing
  alias Argos.Memory.AutonomousMutations
  alias Argos.Repo

  def create_proposal(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_known_keys()
      |> Map.put_new(:status, "pending")
      |> Map.put_new(:evidence, %{})
      |> Map.put_new(:proposed_action, %{
        "kind" => "operator_review",
        "autonomous_action" => false
      })
      |> Map.put_new(:dedupe_hash, dedupe_hash(attrs))

    Repo.transaction(fn ->
      case %Proposal{} |> Proposal.changeset(attrs) |> Repo.insert() do
        {:ok, proposal} ->
          case AutonomousMutations.maybe_apply(proposal) do
            {:auto_applied, proposal, _mutation} ->
              proposal

            {:approval_required, _reason} ->
              {:ok, approval} =
                Approvals.create_approval(%{
                  subject_type: "proposal",
                  subject_id: proposal.id,
                  action: "proposal_review",
                  risk_level: proposal.risk_level,
                  status: "pending",
                  proposal: %{
                    "proposal_id" => proposal.id,
                    "type" => proposal.type,
                    "title" => proposal.title,
                    "proposed_action" => proposal.proposed_action
                  },
                  reason: proposal.summary
                })

              proposal
              |> change(approval_id: approval.id)
              |> Repo.update!()

            {:error, reason} ->
              Repo.rollback(reason)
          end

        {:error, %Ecto.Changeset{errors: [dedupe_hash: _]} = changeset} ->
          Repo.rollback({:error, changeset})

        {:error, changeset} ->
          Repo.rollback({:error, changeset})
      end
    end)
    |> case do
      {:ok, proposal} -> {:ok, proposal}
      {:error, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  def detect(attrs) when is_map(attrs) do
    detector_names = map_value(attrs, "detectors") || ["contradiction", "gap"]

    detector_names
    |> Enum.flat_map(fn
      "contradiction" -> ContradictionDetector.detect(attrs)
      "gap" -> GapDetector.detect(attrs)
      _other -> []
    end)
    |> Enum.map(&create_proposal/1)
  end

  def list_proposals(opts \\ []) do
    Proposal
    |> maybe_filter_status(Keyword.get(opts, :status))
    |> order_by([proposal], desc: proposal.inserted_at)
    |> Repo.all()
  end

  def get_proposal!(id), do: Repo.get!(Proposal, id)

  def stats do
    pending = list_proposals(status: "pending")

    %{
      pending_proposal_count: length(pending),
      pending_proposals: Enum.take(pending, 5)
    }
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [proposal], proposal.status == ^status)
  end

  defp dedupe_hash(attrs) do
    Hashing.sha256(%{
      type: map_value(attrs, "type"),
      canon: map_value(attrs, "canon"),
      canon_version: map_value(attrs, "canon_version"),
      title: map_value(attrs, "title"),
      evidence: map_value(attrs, "evidence"),
      detector_version: map_value(attrs, "detector_version")
    })
  end

  defp normalize_known_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      pair -> pair
    end)
  end

  defp known_key("type"), do: :type
  defp known_key("canon"), do: :canon
  defp known_key("canon_version"), do: :canon_version
  defp known_key("status"), do: :status
  defp known_key("title"), do: :title
  defp known_key("summary"), do: :summary
  defp known_key("evidence"), do: :evidence
  defp known_key("proposed_action"), do: :proposed_action
  defp known_key("risk_level"), do: :risk_level
  defp known_key("approval_id"), do: :approval_id
  defp known_key("detector_version"), do: :detector_version
  defp known_key("dedupe_hash"), do: :dedupe_hash
  defp known_key(key), do: key

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
