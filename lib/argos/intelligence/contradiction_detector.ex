defmodule Argos.Intelligence.ContradictionDetector do
  @moduledoc """
  Rule-based contradiction detector v0.
  """

  @version "contradiction_detector_v0"

  def version, do: @version

  def detect(attrs) when is_map(attrs) do
    canon = map_value(attrs, "canon") || "operator"
    canon_version = map_value(attrs, "canon_version")
    claims = map_value(attrs, "claims") || []

    claims
    |> Enum.group_by(&Map.get(&1, "topic"))
    |> Enum.flat_map(fn {topic, topic_claims} ->
      values =
        topic_claims
        |> Enum.map(&Map.get(&1, "value"))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      if is_binary(topic) and length(values) > 1 do
        [
          %{
            type: "contradiction",
            canon: canon,
            canon_version: canon_version,
            title: "Contradiction detected: #{topic}",
            summary: "Conflicting explicit claims were found for #{topic}.",
            evidence: %{"topic" => topic, "claims" => topic_claims, "values" => values},
            proposed_action: %{
              "kind" => "operator_review",
              "autonomous_action" => false,
              "suggested_next_step" => "Draft a canon clarification if the operator agrees."
            },
            risk_level: "medium",
            detector_version: @version
          }
        ]
      else
        []
      end
    end)
  end

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
