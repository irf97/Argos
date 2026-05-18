defmodule Argos.Context.Renderers.JSON do
  @moduledoc """
  JSON renderer for ARGOS context packs.
  """

  def render(payload) when is_map(payload), do: payload
end
