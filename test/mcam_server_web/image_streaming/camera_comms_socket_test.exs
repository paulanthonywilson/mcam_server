defmodule McamServerWeb.ImageStreaming.CameraCommsSocketTest do
  use McamServerWeb.ConnCase, async: true

  import McamServer.CamerasFixtures

  alias McamServerWeb.ImageStreaming.CameraCommsSocket
  alias McamServer.Cameras

  describe "initiation" do
    test "camera ok" do
      camera = camera_fixture()
      camera_id = camera.id

      connect_map =
        camera
        |> Cameras.token_for(:camera)
        |> req()

      assert {:ok, %{camera_id: ^camera_id}} = CameraCommsSocket.connect(connect_map)
    end

    test "invalid token" do
      assert :error == CameraCommsSocket.connect(req("blah"))
    end

    test "expired token" do
      assert :error == CameraCommsSocket.connect(req(expired_token()))
    end

    test "token for camera that is no longer there" do
      req =
        -1
        |> Cameras.token_for(:camera)
        |> req()

      assert :error == CameraCommsSocket.connect(req)
    end
  end

  describe "init" do
    test "initiates a token refresh" do
      state = %{camera_id: 1234}
      assert {:ok, ^state} = CameraCommsSocket.init(state)

      assert_receive :refresh_token
    end
  end

  describe "refreshing a token" do
    test "sends the new token" do
      %{id: camera_id} = camera_fixture()
      state = %{camera_id: camera_id}

      assert {:push, {:binary, message}, ^state} =
               CameraCommsSocket.handle_info(:refresh_token, state)

      assert {:token_refresh, token} = :erlang.binary_to_term(message)
      assert {:ok, %{id: ^camera_id}} = Cameras.from_token(token, :camera)
    end
  end

  describe "receiving image" do
    test "broadcasts the image" do
      %{id: camera_id} = camera_fixture()

      Cameras.subscribe_to_camera(camera_id)
      state = %{camera_id: camera_id}

      image = <<0xFF, 0xD8, 0xFF>> <> "not really an image"

      assert {:reply, :ok, {:binary, <<0x0A>>}, ^state} =
               CameraCommsSocket.handle_in({image, [opcode: :binary]}, state)

      assert_receive {:camera_image, ^camera_id, ^image}
    end
  end

  defp req(token) do
    %{params: %{"token" => token}, transport: :websocket}
  end

  defp expired_token do
    secrets = Application.fetch_env!(:mcam_server, :camera_token)
    Plug.Crypto.encrypt(secrets[:secret], secrets[:salt], 1, signed_at: 0)
  end
end
