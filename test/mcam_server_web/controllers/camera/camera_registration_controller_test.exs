defmodule McamServerWeb.Camera.CameraRegistrationControllerTest do
  use McamServerWeb.ConnCase, async: true
  import McamServer.AccountsFixtures

  alias McamServer.{Cameras, Subscriptions}

  setup do
    %{user: user_fixture(email: "bob@mavis.com", password: "marvinmarvinmarvin")}
  end

  test "successfully registering a camera", %{conn: conn, user: %{id: user_id}} do
    conn =
      post(conn, Routes.camera_registration_path(conn, :create), %{
        email: "bob@mavis.com",
        password: "marvinmarvinmarvin",
        board_id: "c3p0"
      })

    assert response = json_response(conn, 200)

    assert {:ok, %{board_id: "c3p0", owner_id: ^user_id}} = Cameras.from_token(response, :camera)
  end

  test "invalid user details", %{conn: conn} do
    conn =
      post(conn, Routes.camera_registration_path(conn, :create), %{
        email: "bob@mavis.com",
        password: "nope",
        board_id: "c3p0"
      })

    assert json_response(conn, 401)
  end

  test "quota_exceeded", %{user: user, conn: conn} do
    {_, quota} = Subscriptions.camera_quota(user)

    for i <- 1..quota do
      {:ok, _} = Cameras.register("bob@mavis.com", "marvinmarvinmarvin", "r#{i}d#{i}")
    end

    conn =
      post(conn, Routes.camera_registration_path(conn, :create), %{
        email: "bob@mavis.com",
        password: "marvinmarvinmarvin",
        board_id: "c3p0"
      })

    assert json_response(conn, 402)
  end

  test "400 response without the required params", %{conn: conn} do
    assert conn
           |> post(Routes.camera_registration_path(conn, :create), %{})
           |> json_response(400)
  end

  test "recording an unregistered camera", %{conn: conn} do
    %{remote_ip: remote_ip} = conn
    McamServer.UnregisteredCameras.subscribe()

    assert conn
           |> post(Routes.camera_registration_path(conn, :unregistered_camera), %{
             hostname: "mine-host",
             local_ip: "192.168.2.3"
           })
           |> json_response(200)

    assert_receive {McamServer.UnregisteredCameras, :update,
                    {^remote_ip, "mine-host", "192.168.2.3"}}
  end
end
