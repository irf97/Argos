defmodule ArgosWeb.Api.HealthController do
  use ArgosWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
