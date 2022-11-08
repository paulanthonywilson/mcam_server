# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mcam_server,
  ecto_repos: [McamServer.Repo]

# Configures the endpoint
config :mcam_server, McamServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: McamServerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: McamServer.PubSub,
  live_view: [signing_salt: "Fs+L7r6Z"]

{server_url, server_ws} =
  case Mix.env() do
    :dev -> {"http://localhost:4600", "ws://localhost:4600"}
    _ -> {"https://mcam.iscodebaseonfire.com", "wss://mcam.iscodebaseonfire.com"}
  end

config :mcam_server, server_url: server_url, server_ws: server_ws
# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
