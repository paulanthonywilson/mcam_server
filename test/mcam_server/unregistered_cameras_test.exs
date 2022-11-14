defmodule McamServer.UnregisteredCamerasTest do
  use ExUnit.Case, async: true

  alias McamServer.UnregisteredCameras

  import McamServer.UnregisteredCamerasSupport
  import TestHelpers

  setup do
    registry_name = self() |> inspect() |> String.to_atom()
    {:ok, _pid} = Registry.start_link(keys: :unique, name: registry_name)

    {:ok, unregistered_cameras} = UnregisteredCameras.start_link(registry_name: registry_name)

    {:ok, unregistered_cameras: unregistered_cameras}
  end

  test "adding and retrieving cameras", %{unregistered_cameras: unregistered_cameras} do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    assert [{"nerves-b4lx", "10.20.0.21"}] ==
             UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
  end

  test "multiple registrations from remote ip", %{unregistered_cameras: unregistered_cameras} do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4ld", "10.20.0.22"}
      )

    assert [{"nerves-b4ld", "10.20.0.22"}, {"nerves-b4lx", "10.20.0.21"}] ==
             UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
  end

  test "updating a camera", %{unregistered_cameras: unregistered_cameras} do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.22"}
      )

    assert [{"nerves-b4lx", "10.20.0.22"}] ==
             UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
  end

  test "cameras from ip only returns cameras from a particular remote ip", %{
    unregistered_cameras: unregistered_cameras
  } do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 215}, "nerves-other", "10.20.0.22"}
      )

    assert [{"nerves-b4lx", "10.20.0.21"}] ==
             UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
  end

  test "timing out", %{unregistered_cameras: unregistered_cameras} do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    expire_camera(unregistered_cameras, "nerves-b4lx")

    assert [] ==
             wait_until_equals([], fn ->
               UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
             end)
  end

  test "timeout and update race condition",
       %{unregistered_cameras: unregistered_cameras} do
    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    expire_camera(unregistered_cameras, "nerves-b4lx")

    :ok =
      UnregisteredCameras.record_camera_from_ip(
        unregistered_cameras,
        {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
      )

    assert [{"nerves-b4lx", "10.20.0.21"}] ==
             UnregisteredCameras.cameras_from_ip(unregistered_cameras, {83, 52, 11, 214})
  end

  describe "notification" do
    setup %{unregistered_cameras: unregistered_cameras} do
      :ok = UnregisteredCameras.subscribe(unregistered_cameras)
      :ok
    end

    test "notified on new registration", %{unregistered_cameras: unregistered_cameras} do
      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
        )

      assert_receive {^unregistered_cameras, :update,
                      {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}}
    end

    test "notified of updates", %{unregistered_cameras: unregistered_cameras} do
      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
        )

      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.22"}
        )

      assert_receive {^unregistered_cameras, :update,
                      {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.22"}}
    end

    test "not notified of updates if no change has been made", %{
      unregistered_cameras: unregistered_cameras
    } do
      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
        )

      assert_receive {^unregistered_cameras, :update, _}

      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
        )

      refute_receive {^unregistered_cameras, :update, _}
    end

    test "notified when removed from registry", %{unregistered_cameras: unregistered_cameras} do
      :ok =
        UnregisteredCameras.record_camera_from_ip(
          unregistered_cameras,
          {{83, 52, 11, 214}, "nerves-b4lx", "10.20.0.21"}
        )

      expire_camera(unregistered_cameras, "nerves-b4lx")

      assert_receive {^unregistered_cameras, :removed, "nerves-b4lx"}
    end
  end
end
