defmodule McamServerWeb.UnregisteredCamerasController do
  use McamServerWeb, :controller

  alias McamServerWeb.UnregisteredCamerasLive
  import Phoenix.LiveView.Controller, only: [live_render: 3]

  def index(%{remote_ip: remote_ip} = conn, _params) do
    live_render(conn, UnregisteredCamerasLive, session: %{"remote_ip" => remote_ip})
  end
end
