defmodule McamWeb.RootControllerTest do
  use McamServerWeb.ConnCase, async: true

  test "redirects to the landing page when unauthorised", %{conn: conn} do
    conn = get(conn, Routes.root_path(conn, :index))
    assert redirected_to(conn) == Routes.page_path(conn, :index)
  end

  test "redirects to the camera page when authorised", ctx do
    %{conn: conn} = register_and_log_in_user(ctx)
    conn = get(conn, Routes.root_path(conn, :index))
    assert redirected_to(conn) == Routes.camera_path(conn, :index)
  end
end
