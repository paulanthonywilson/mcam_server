defmodule McamServer.UnregisteredCamerasSupport do
  @moduledoc """
  Testing support for unregisted cameras
  """
  def expire_camera(unregistered_cameras \\ McamServer.UnregisteredCameras, hostname) do
    %{registry: registry} = :sys.get_state(unregistered_cameras)
    [{pid, _}] = Registry.lookup(registry, hostname)
    send(pid, :timeout)
  end
end
