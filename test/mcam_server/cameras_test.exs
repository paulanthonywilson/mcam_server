defmodule McamServer.CamerasTest do
  use McamServer.DataCase, async: true

  alias McamServer.{AccountsFixtures, CamerasFixtures, Cameras, Cameras.Camera, Subscriptions}

  setup do
    user = AccountsFixtures.user_fixture(%{email: "bob@bob.com", password: "hellomateyboy"})
    Cameras.subscribe_to_registrations(user)
    {:ok, user: user}
  end

  describe "register camera" do
    test "when the camera is new, the user exists, and the password is correct", %{
      user: %{id: user_id}
    } do
      assert {:ok, %Camera{owner_id: ^user_id, board_id: "00af8", id: camera_id, name: "00af8"}} =
               Cameras.register("bob@bob.com", "hellomateyboy", "00af8")

      assert_receive {:camera_registration, %{id: ^camera_id}}
    end

    test "when the password is invalid" do
      assert {:error, :authentication_failure} =
               Cameras.register("bob@bob.com", "password", "r2d2")
    end

    test "when the user is invalid" do
      assert {:error, :authentication_failure} =
               Cameras.register("bob@bobbbles.com", "password", "r2d2")
    end

    test "no-op but returns the original camera if the camera is already registered, but does not broadcast" do
      {:ok, %Camera{id: camera_id}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")
      assert_receive {:camera_registration, %{id: ^camera_id}}

      assert {:ok, %Camera{id: ^camera_id}} =
               Cameras.register("bob@bob.com", "hellomateyboy", "bb8")

      refute_receive {:camera_registration, %{id: ^camera_id}}
    end

    test "registering two cameras" do
      {:ok, %Camera{id: camera_id1}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")
      {:ok, %Camera{id: camera_id2}} = Cameras.register("bob@bob.com", "hellomateyboy", "c3p0")

      assert camera_id1 != camera_id2
    end

    test "registering over quota", %{user: user} do
      {_, quota} = Subscriptions.camera_quota(user)

      for _ <- 1..quota do
        {:ok, _} = Cameras.register("bob@bob.com", "hellomateyboy", "x#{System.unique_integer()}")
      end

      assert {:error, :quota_exceeded} ==
               Cameras.register("bob@bob.com", "hellomateyboy", "busted")
    end

    test "registing the same board id with a different user is treated like separate cameras" do
      AccountsFixtures.user_fixture(%{email: "bob2@bob.com", password: "ohbobmybobbybob"})
      {:ok, %Camera{id: camera_id1}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")
      {:ok, %Camera{id: camera_id2}} = Cameras.register("bob2@bob.com", "ohbobmybobbybob", "bb8")

      assert camera_id1 != camera_id2
    end
  end

  describe "camera tokenisation" do
    test "can generate and retrieve camera from token", %{user: %{id: user_id}} do
      {:ok, %{id: camera_id} = camera} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")

      token = Cameras.token_for(camera, :camera)

      assert is_binary(token)

      assert {:ok, %Camera{id: ^camera_id, owner_id: ^user_id, board_id: "bb8"}} =
               Cameras.from_token(token, :camera)
    end

    test "tokenising with only the camera id", %{user: %{id: user_id}} do
      {:ok, %{id: camera_id}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")

      token = Cameras.token_for(camera_id, :camera)

      assert {:ok, %Camera{id: ^camera_id, owner_id: ^user_id, board_id: "bb8"}} =
               Cameras.from_token(token, :camera)
    end

    test "invalid token" do
      assert {:error, :invalid} == Cameras.from_token("hello sailor", :camera)
    end

    test "no such camera" do
      token = Cameras.token_for(%Camera{id: -999}, :camera)
      assert {:error, :not_found} == Cameras.from_token(token, :camera)
    end

    test "browser tokens also work", %{user: %{id: user_id}} do
      {:ok, %{id: camera_id}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")

      token = Cameras.token_for(camera_id, :browser)

      assert {:ok, %Camera{id: ^camera_id, owner_id: ^user_id, board_id: "bb8"}} =
               Cameras.from_token(token, :browser)
    end

    test "browser and camera tokens are not compatible" do
      {:ok, %{id: camera_id}} = Cameras.register("bob@bob.com", "hellomateyboy", "bb8")

      token = Cameras.token_for(camera_id, :browser)

      assert {:error, :invalid} = Cameras.from_token(token, :camera)
    end
  end

  test "subscribing to camera" do
    %{id: camera_id} = CamerasFixtures.camera_fixture()

    :ok = Cameras.subscribe_to_camera(camera_id)
    :ok = Cameras.broadcast_image(camera_id, "pretend image")

    assert_receive {:camera_image, ^camera_id, "pretend image"}
  end

  test "cameras for user ", %{user: user} do
    bystander = AccountsFixtures.user_fixture(password: "012345678901")
    for i <- 1..5, do: {:ok, _} = Cameras.register("bob@bob.com", "hellomateyboy", "r#{i}d#{i}")
    {:ok, _} = Cameras.register(bystander.email, "012345678901", "other")

    assert ["r1d1", "r2d2", "r3d3", "r4d4", "r5d5"] =
             user
             |> Cameras.user_cameras()
             |> Enum.map(& &1.board_id)
  end

  describe "update camera name" do
    test "can succeed" do
      camera = CamerasFixtures.camera_fixture()

      assert {:ok, %Camera{name: "Bobby the great"}} =
               Cameras.change_name(camera, "Bobby the great")

      assert {:ok, %{name: "Bobby the great"}} =
               camera
               |> Cameras.token_for(:browser)
               |> Cameras.from_token(:browser)
    end

    test "subscribing to name change" do
      camera = CamerasFixtures.camera_fixture()
      Cameras.subscribe_to_name_change(camera)
      {:ok, _} = Cameras.change_name(camera, "Oh Ferdinand")
      assert_receive {:camera_name_change, %Camera{name: "Oh Ferdinand"}}
    end

    test "name can't be blank" do
      camera = CamerasFixtures.camera_fixture()
      Cameras.subscribe_to_name_change(camera)
      assert {:error, _} = Cameras.change_name(camera, "")
      refute_receive {:camera_name_change, _}
    end
  end

  describe "guest cameras" do
    test "lists guest cameras", %{user: user} do
      camera = CamerasFixtures.camera_fixture()
      CamerasFixtures.add_guest(camera, user)
      assert [camera] == Cameras.guest_cameras(user)
    end
  end
end
