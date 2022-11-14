defmodule McamServer.Mailer do
  use Swoosh.Mailer, otp_app: :mcam_server

  alias Swoosh.Email

  def send_email(to, subject, body) do
    require Logger

    email =
      Email.new()
      |> Email.from(from())
      |> Email.to(to)
      |> Email.subject(subject)
      |> Email.text_body(body)

    {:ok, _} = deliver(email)

    {:ok, email}
  end

  def from do
    env = Application.fetch_env!(:mcam_server, __MODULE__)

    case env[:from] do
      nil ->
        "noreply@#{Keyword.fetch!(env, :domain)}"

      res ->
        res
    end
  end
end
