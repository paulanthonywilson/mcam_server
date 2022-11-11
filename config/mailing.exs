import Config

# Mailer
case Mix.env() do
  :test ->
    config :mcam_server, McamServer.Mailer, adapter: Swoosh.Adapters.Local
    config :swoosh, :api_client, false

  _ ->
    config :mcam_server, McamServer.Mailer, adapter: Swoosh.Adapters.Sendgrid
    secret_mail = Path.join(__DIR__, "mailing.secret.exs")
    if File.exists?(secret_mail), do: import_config(secret_mail)
end
