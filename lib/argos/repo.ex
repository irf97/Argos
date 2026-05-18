defmodule Argos.Repo do
  use Ecto.Repo,
    otp_app: :argos,
    adapter: Ecto.Adapters.Postgres
end
