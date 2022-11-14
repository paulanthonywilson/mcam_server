defmodule McamServerWeb.UnregisteredCamerasLiveTest do
  use McamServerWeb.ConnCase, async: true

  import McamServer.AccountsFixtures

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias McamServer.UnregisteredCameras

  import McamServer.UnregisteredCamerasSupport

  setup_all do
    {:ok, counter} = Agent.start_link(fn -> 2 end)
    {:ok, counter: counter}
  end

  setup %{conn: conn, counter: counter} do
    count = Agent.get_and_update(counter, fn i -> {i, i + 1} end)

    # Modify the remote ip to avoid cross-contamination between tests
    # (The live view only lists cameras from the remote ip)
    remote_ip = {157, 35, 2, count}

    user = user_fixture()
    :ok = UnregisteredCameras.subscribe()

    conn =
      conn
      |> log_in_user(user)
      |> Map.put(:remote_ip, remote_ip)

    {:ok, conn: conn, user: user, remote_ip: remote_ip}
  end

  test "no registered cameras", %{conn: conn} do
    {:ok, _view, html} = live(conn, Routes.unregistered_cameras_path(conn, :index))
    assert html =~ "No unregistered cameras"
  end

  test "Lists registered cameras", %{conn: conn, remote_ip: remote_ip} do
    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.23"})
    {:ok, _view, html} = live(conn, Routes.unregistered_cameras_path(conn, :index))

    assert html =~ "nerves-bb12"
    assert html =~ "http://10.20.1.23:4000"
  end

  test "adds registered cameras when one arrives on the scene", %{
    conn: conn,
    remote_ip: remote_ip
  } do
    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-c3p0", "10.20.1.30"})
    {:ok, view, _html} = live(conn, Routes.unregistered_cameras_path(conn, :index))

    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.23"})
    :sys.get_state(UnregisteredCameras)
    html = render(view)
    assert html =~ "nerves-bb12"
    assert html =~ "http://10.20.1.23:4000"
    assert html =~ "http://10.20.1.30:4000"
  end

  test "updates ammend the existing camera listing rather than duplicating it", %{
    conn: conn,
    remote_ip: remote_ip
  } do
    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.23"})
    {:ok, view, _html} = live(conn, Routes.unregistered_cameras_path(conn, :index))

    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.24"})
    :sys.get_state(UnregisteredCameras)
    html = render(view)
    assert html =~ "http://10.20.1.24:4000"
    refute html =~ "http://10.20.1.23:4000"
  end

  test "does not list new cameras from other ips", %{conn: conn} do
    {:ok, view, _html} = live(conn, Routes.unregistered_cameras_path(conn, :index))

    UnregisteredCameras.record_camera_from_ip({{192, 168, 1, 1}, "nerves-bb12", "10.20.1.23"})
    :sys.get_state(UnregisteredCameras)
    html = render(view)
    refute html =~ "nerves-bb12"
  end

  test "camera updated to be on a different remote ip is removed", %{
    conn: conn,
    remote_ip: remote_ip
  } do
    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.23"})
    {:ok, view, _html} = live(conn, Routes.unregistered_cameras_path(conn, :index))

    UnregisteredCameras.record_camera_from_ip({{192, 168, 1, 1}, "nerves-bb12", "10.20.1.23"})
    :sys.get_state(UnregisteredCameras)
    html = render(view)
    refute html =~ "nerves-bb12"
  end

  test "camera expires", %{conn: conn, remote_ip: remote_ip} do
    UnregisteredCameras.record_camera_from_ip({remote_ip, "nerves-bb12", "10.20.1.23"})
    {:ok, view, _html} = live(conn, Routes.unregistered_cameras_path(conn, :index))
    expire_camera("nerves-bb12")

    wait_until_equals(false, fn -> render(view) =~ "nerves-bb12" end)
    html = render(view)
    refute html =~ "nerves-bb12"
  end
end
