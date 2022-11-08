defmodule McamServerWeb.PageController do
  use McamServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
