defmodule McamServer.UnregisteredCameras.UnregisteredCameraEvents do
  @moduledoc """
  Notification events for unregistered cameras
  """

  @unregistered_camera_broadcaster_name __MODULE__

  def registry_name, do: @unregistered_camera_broadcaster_name

  def subscribe(topic) do
    {:ok, _} = Registry.register(@unregistered_camera_broadcaster_name, topic, [])
    :ok
  end

  def broadcast(topic, event) do
    Registry.dispatch(@unregistered_camera_broadcaster_name, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, event)
    end)
  end
end
