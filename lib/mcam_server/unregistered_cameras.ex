defmodule McamServer.UnregisteredCameras do
  @moduledoc """
  Holds a registry of unregistered cameras with their remote IP, hostname, and their IP on the local network.
  The registry is held in memory and each entry expires after 65 seconds, if it is not updated.

  """

  use GenServer

  @default_name __MODULE__

  alias McamServer.UnregisteredCameras.{
    UnregisteredCameraEntry,
    UnregisteredCameraEvents,
    UnregisteredCameraEntrySupervisor
  }

  def default_name, do: @default_name

  def start_link(opts) do
    {registry_name, opts} = Keyword.pop!(opts, :registry_name)
    GenServer.start_link(__MODULE__, registry_name, opts)
  end

  def init(registry) do
    {:ok, %{registry: registry}}
  end

  def subscribe(server \\ @default_name) do
    UnregisteredCameraEvents.subscribe(server)
  end

  def record_camera_from_ip(server \\ @default_name, {_ip, _hostname, _local_ip} = details) do
    GenServer.cast(server, {:record_camera_from_ip, details, server})
  end

  def cameras_from_ip(server \\ @default_name, ip) do
    GenServer.call(server, {:cameras_from_ip, ip})
  end

  def handle_call({:cameras_from_ip, ip}, _from, %{registry: registry} = state) do
    cameras =
      Registry.select(registry, [
        {{:"$1", :_, {:"$2", :"$3"}}, [{:==, :"$2", inspect(ip)}], [{{:"$1", :"$3"}}]}
      ])

    {:reply, cameras, state}
  end

  def handle_cast(
        {:record_camera_from_ip, {ip, hostname, local_ip}, server},
        %{registry: registry} = state
      ) do
    case Registry.lookup(registry, hostname) do
      [{entry_pid, _}] ->
        update_entry(entry_pid, registry, {ip, hostname, local_ip})

      [] ->
        new_entry({server, registry}, {ip, hostname, local_ip})
    end

    {:noreply, state}
  end

  defp update_entry(entry_pid, registry, {ip, hostname, local_ip} = entry) do
    :ok = UnregisteredCameraEntry.update_entry(entry_pid, ip, hostname, local_ip)
  catch
    :exit, _ ->
      new_entry({NoNooooooooooooom, registry}, entry)
  end

  defp new_entry(identifiers, {ip, hostname, local_ip}) do
    {:ok, _pid} =
      UnregisteredCameraEntrySupervisor.create_new_registry_entry(
        identifiers,
        ip,
        hostname,
        local_ip
      )
  end
end
