defmodule McamServerWeb.RootController do
  use McamServerWeb, :controller

  def index(%{assigns: assigns} = conn, _params) do
    if assigns[:current_user] do
      redirect(conn, to: Routes.camera_path(conn, :index))
    else
      redirect(conn, to: Routes.page_path(conn, :index))
    end
  end

  def ok(conn, _) do
    text(conn, "ok")
  end
end
