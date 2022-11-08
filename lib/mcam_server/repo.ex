defmodule McamServer.Repo do
  use Ecto.Repo,
    otp_app: :mcam_server,
    adapter: Ecto.Adapters.Postgres
end
