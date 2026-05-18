defmodule Argos.Intelligence.GapDetector do
  @moduledoc """
  Rule-based gap detector v0.
  """

  @version "gap_detector_v0"

  def version, do: @version

  def detect(attrs) when is_map(attrs) do
    canon = map_value(attrs, "canon") || "operator"
    canon_version = map_value(attrs, "canon_version")
    required_topics = map_value(attrs, "required_topics") || []
    present_topics = map_value(attrs, "present_topics") || []
    missing_topics = required_topics -- present_topics

    if missing_topics == [] do
      []
    else
      [
        %{
          type: "gap",
          canon: canon,
          canon_version: canon_version,
          title: "Doctrine gap detected",
          summary: "Required topics are missing from the explicit context.",
          evidence: %{
            "required_topics" => required_topics,
            "present_topics" => present_topics,
            "missing_topics" => missing_topics
          },
          proposed_action: %{
            "kind" => "operator_review",
            "autonomous_action" => false,
            "suggested_next_step" => "Draft canon or doctrine coverage for missing topics."
          },
          risk_level: "low",
          detector_version: @version
        }
      ]
    end
  end

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
