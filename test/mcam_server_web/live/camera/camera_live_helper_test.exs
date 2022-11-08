defmodule McamServerWeb.CameraLiveHelperTest do
  use McamServerWeb.ConnCase

  import McamServer.AccountsFixtures
  import McamServer.CamerasFixtures

  alias McamServer.{Accounts, Cameras}
  alias McamServerWeb.CameraLiveHelper

  alias Phoenix.LiveView.Socket

  describe "select camera" do
    setup do
      password = "veryslowredfox"
      user = user_fixture(%{password: password})
      host_user = user_fixture(%{password: password})
      cameras = for _i <- 1..5, do: user_camera_fixture(user, password)
      guest_cameras = for _i <- 1..5, do: user_camera_fixture(host_user, password)
      socket = %{assigns: %{all_cameras: cameras, guest_cameras: guest_cameras}}
      Map.merge(%{user: user, socket: socket}, socket.assigns)
    end

    test "when in params and own camera list", %{socket: socket, all_cameras: cameras} do
      [_, cam2 | _] = cameras

      assert CameraLiveHelper.selected_camera(%{"camera_id" => cam2.id}, socket) == cam2
    end

    test "param is a string", %{all_cameras: cameras, socket: socket} do
      [_, cam2 | _] = cameras

      assert CameraLiveHelper.selected_camera(%{"camera_id" => to_string(cam2.id)}, socket) ==
               cam2
    end

    test "params is wrong, but list is not empty", %{all_cameras: cameras, socket: socket} do
      [first | _] = cameras

      assert CameraLiveHelper.selected_camera(%{"camera_id" => -1}, socket) == first
    end

    test "no camera_id in params", %{socket: socket, all_cameras: cameras} do
      [first | _] = cameras
      assert CameraLiveHelper.selected_camera(%{}, socket) == first
    end

    test "no camera id in params and empty params" do
      assert CameraLiveHelper.selected_camera(%{}, %{assigns: %{all_cameras: []}}) == :no_camera
    end

    test "camera id in params but no cameras", %{socket: socket} do
      socket = Map.update!(socket, :assigns, &%{&1 | all_cameras: []})
      assert CameraLiveHelper.selected_camera(%{"camera_id" => 12}, socket) == :no_camera
    end
  end

  describe "select guest camera" do
    setup do
      user = user_fixture()

      guest_cameras =
        [_, guest_camera | _] =
        for _ <- 1..3 do
          camera = camera_fixture()
          add_guest(camera, user)
          camera
        end

      {:ok,
       socket: %Socket{assigns: %{all_cameras: [], guest_cameras: guest_cameras, user: user}},
       guest_camera: guest_camera}
    end

    test "valid guest camera in params returns camera", %{
      socket: socket,
      guest_camera: guest_camera
    } do
      assert CameraLiveHelper.selected_guest_camera(
               %{"camera_id" => to_string(guest_camera.id)},
               socket
             ) ==
               guest_camera
    end

    test "without camera id, there is no camera", %{socket: socket} do
      assert CameraLiveHelper.selected_guest_camera(%{}, socket) == :no_camera
    end

    test "with wrong camera id, there is no camera", %{socket: socket} do
      assert CameraLiveHelper.selected_guest_camera(%{"camera_id" => "-11"}, socket) == :no_camera
    end

    test "with invalid camera id, there is no camera", %{socket: socket} do
      assert CameraLiveHelper.selected_guest_camera(%{"camera_id" => "bob"}, socket) == :no_camera
    end
  end

  describe "update camera" do
    setup do
      [camera | _] = all_cameras = for i <- 1..5, do: %{id: i, name: "Camera #{i}"}
      guest_cameras = [%{id: 20, name: "guest cameras"}]

      {:ok,
       socket: %{
         assigns: %{camera: camera, all_cameras: all_cameras, guest_cameras: guest_cameras}
       }}
    end

    test "when camera is current, return replacment as current", %{socket: socket} do
      assert {%{id: 1, name: "bobby"}, _, _} =
               CameraLiveHelper.update_camera(%{id: 1, name: "bobby"}, socket)
    end

    test "when camera is not current, do not replace", %{socket: socket} do
      assert {%{id: 1, name: "Camera 1"}, _, _} =
               CameraLiveHelper.update_camera(%{id: 2, name: "bobby"}, socket)
    end

    test "updates camera in all cameras", %{socket: socket} do
      assert {_, [%{id: 1, name: "bobby"} | _], _} =
               CameraLiveHelper.update_camera(%{id: 1, name: "bobby"}, socket)

      assert {_, [_, %{id: 2, name: "mavis"} | _], _} =
               CameraLiveHelper.update_camera(%{id: 2, name: "mavis"}, socket)
    end

    test "updates guest camera", %{socket: socket} do
      assert {_, _, [%{id: 20, name: "Bobby Ewing"}]} =
               CameraLiveHelper.update_camera(%{id: 20, name: "Bobby Ewing"}, socket)
    end

    test "no change when not in lists", %{
      socket:
        %{assigns: %{camera: camera, all_cameras: all_cameras, guest_cameras: guest_cameras}} =
          socket
    } do
      assert {^camera, ^all_cameras, ^guest_cameras} =
               CameraLiveHelper.update_camera(%{id: 11, name: "dunno"}, socket)
    end
  end

  describe "mount cameras" do
    setup do
      user = user_fixture(%{password: "a long password"})

      user_cameras = for _ <- 1..5, do: user_camera_fixture(user, "a long password")

      other_user = user_fixture()

      guest_cameras =
        for _ <- 1..3 do
          camera = user_camera_fixture(other_user)
          add_guest(camera, user)
          camera
        end

      session = %{
        "user_token" => Accounts.generate_user_session_token(user)
      }

      {:ok,
       user: user, user_cameras: user_cameras, guest_cameras: guest_cameras, session: session}
    end

    test "returns ok and socket", %{session: session} do
      assert {:ok, %Socket{}} = CameraLiveHelper.mount_camera(%{}, session, %Socket{})
    end

    test "assigns the user", %{session: session, user: user} do
      assert {:ok, %{assigns: %{user: ^user}}} =
               CameraLiveHelper.mount_camera(%{}, session, %Socket{})
    end

    test "assigns the user's cameras", %{session: session, user_cameras: user_cameras} do
      assert {:ok, %{assigns: %{all_cameras: ^user_cameras}}} =
               CameraLiveHelper.mount_camera(%{}, session, %Socket{})
    end

    test "counts the user's cameras", %{session: session, user_cameras: user_cameras} do
      assert {:ok, %{assigns: %{all_camera_count: camera_count}}} =
               CameraLiveHelper.mount_camera(%{}, session, %Socket{})

      assert camera_count == length(user_cameras)
    end

    test "assigns guest cameras", %{session: session, guest_cameras: guest_cameras} do
      assert {:ok, %{assigns: %{guest_cameras: ^guest_cameras}}} =
               CameraLiveHelper.mount_camera(%{}, session, %Socket{})
    end

    test "assigns subscription quota and type", %{session: session} do
      assert {:ok, %{assigns: %{camera_quota: quota, subscription_plan: subscription_plan}}} =
               CameraLiveHelper.mount_camera(%{}, session, %Socket{})

      assert is_atom(subscription_plan)
      assert is_integer(quota)
    end

    test "subscribes to user camera name changes", %{session: session, user_cameras: [camera | _]} do
      {:ok, _} = CameraLiveHelper.mount_camera(%{}, session, %Socket{})
      Cameras.change_name(camera, "sue")
      assert_received {:camera_name_change, %{name: "sue"}}
    end

    test "subscribes to guest camera name changes", %{
      session: session,
      guest_cameras: [camera | _]
    } do
      {:ok, _} = CameraLiveHelper.mount_camera(%{}, session, %Socket{})
      Cameras.change_name(camera, "rita")
      assert_received {:camera_name_change, %{name: "rita"}}
    end

    test "subscribes to registrations", %{session: session, user: user} do
      {:ok, _} = CameraLiveHelper.mount_camera(%{}, session, %Socket{})
      {:ok, _} = Cameras.register(user.email, "a long password", "new cam")

      assert_received({:camera_registration, %{board_id: "new cam"}})
    end
  end

  test "basic email validation" do
    assert :ok == CameraLiveHelper.basic_email_validate("bob@bob.com")
    assert :bad_email == CameraLiveHelper.basic_email_validate("bob@")
    assert :bad_email == CameraLiveHelper.basic_email_validate("")
    assert :bad_email == CameraLiveHelper.basic_email_validate("@bob.com")
    assert :bad_email == CameraLiveHelper.basic_email_validate("bob.com")
    assert :bad_email == CameraLiveHelper.basic_email_validate("bob@")
    assert :bad_email == CameraLiveHelper.basic_email_validate("bob@bob")
    assert :bad_email == CameraLiveHelper.basic_email_validate("bob@.com")
    assert :ok == CameraLiveHelper.basic_email_validate("bob@bob.abcd")
  end

  test "local network url from board id" do
    assert CameraLiveHelper.local_network_url("00000000352052e9") ==
             "http://nerves-52e9.local:4000"

    assert CameraLiveHelper.local_network_url("") == "http://nerves-.local:4000"

    assert CameraLiveHelper.local_network_url(%{board_id: "00000000352052e9"}) ==
             "http://nerves-52e9.local:4000"
  end
end
