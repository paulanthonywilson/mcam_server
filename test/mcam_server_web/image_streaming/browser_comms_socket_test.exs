defmodule ImageStreaming.BrowserCommsSocketTest do
  use McamServerWeb.ConnCase, async: true

  import McamServer.CamerasFixtures

  alias McamServerWeb.ImageStreaming.BrowserCommsSocket
  alias McamServer.Cameras

  describe "initiation" do
    test "camera ok" do
      camera = camera_fixture()
      camera_id = camera.id

      req =
        camera
        |> Cameras.token_for(:browser)
        |> req()

      assert {:ok, %{camera_id: ^camera_id}} = BrowserCommsSocket.connect(req)
    end

    test "invalid token" do
      assert :error == BrowserCommsSocket.connect(req("blah"))
    end

    test "expired token" do
      assert {:ok, :expired_token} == BrowserCommsSocket.connect(req(expired_token()))
      assert {:ok, :expired_token} == BrowserCommsSocket.init(:expired_token)
      assert_received :expired_token

      assert {:push, {:text, "expired_token"}, :expired_token} ==
               BrowserCommsSocket.handle_info(:expired_token, :expired_token)

      assert_received :close_socket

      assert {:stop, :closed, :expired_token} ==
               BrowserCommsSocket.handle_info(:close_socket, :expired_token)
    end

    test "token for camera that is no longer there" do
      req =
        -1
        |> Cameras.token_for(:browser)
        |> req()

      assert :error == BrowserCommsSocket.connect(req)
    end
  end

  describe "refreshing a token" do
    test "refresh initiated on init" do
      state = %{camera_id: 123}
      assert {:ok, ^state} = BrowserCommsSocket.init(state)
      assert_received :refresh_token
    end

    test "token refreesh" do
      %{id: camera_id} = camera_fixture()
      state = %{camera_id: camera_id}

      assert {:push, {:text, "token:" <> token}, ^state} =
               BrowserCommsSocket.handle_info(:refresh_token, state)

      assert {:ok, %{id: ^camera_id}} = Cameras.from_token(token, :browser)
    end
  end

  test "sending an image" do
    state = %{camera_id: 123}

    assert {:push, {:binary, "Pretend I'm an image"}, ^state} =
             BrowserCommsSocket.handle_info({:camera_image, 123, "Pretend I'm an image"}, state)
  end

  defp req(token) do
    %{params: %{"token" => token}}
  end

  defp expired_token do
    secrets = Application.fetch_env!(:mcam_server, :browser_token)
    Plug.Crypto.encrypt(secrets[:secret], secrets[:salt], 1, signed_at: 0)
  end
end
