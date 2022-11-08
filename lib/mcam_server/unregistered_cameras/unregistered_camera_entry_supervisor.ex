defmodule McamServer.UnregisteredCameras.UnregisteredCameraEntrySupervisor do
  @moduledoc false
  use DynamicSupervisor
  @name __MODULE__

  alias McamServer.UnregisteredCameras.UnregisteredCameraEntry

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: @name)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_new_registry_entry(identifiers, ip, hostname, local_ip) do
    DynamicSupervisor.start_child(
      @name,
      {UnregisteredCameraEntry, {identifiers, ip, hostname, local_ip}}
    )
  end
end
