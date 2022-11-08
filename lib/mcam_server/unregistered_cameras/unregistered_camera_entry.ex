defmodule McamServer.UnregisteredCameras.UnregisteredCameraEntry do
  @moduledoc """
  Process responsible for adding and updating unregistered cameras, timing out the entry
  after 65 seconds.
  """
  use GenServer, restart: :transient

  alias McamServer.UnregisteredCameras.UnregisteredCameraEvents

  @timeout 65_000

  def start_link({{_registry_server, _registry}, _ip, _hostname, _local_ip} = args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init({{registry_server, registry}, ip, host, local_ip}) do
    {:ok, _pid} = Registry.register(registry, host, registry_value(ip, local_ip))
    broadcast_updated(registry_server, {ip, host, local_ip})

    {:ok,
     %{
       registry: registry,
       registry_server: registry_server,
       host: host,
       local_ip: local_ip,
       ip: ip
     }, @timeout}
  end

  def update_entry(pid, ip, host, local_ip) do
    GenServer.call(pid, {:update_entry, ip, host, local_ip})
  end

  def handle_call(
        {:update_entry, ip, host, local_ip},
        _,
        %{host: host, ip: ip, local_ip: local_ip} = state
      ) do
    {:reply, :ok, state, @timeout}
  end

  def handle_call(
        {:update_entry, ip, host, local_ip},
        _,
        %{registry: registry, registry_server: registry_server, host: host} = state
      ) do
    {_, _} = Registry.update_value(registry, host, fn _ -> registry_value(ip, local_ip) end)

    broadcast_updated(registry_server, {ip, host, local_ip})
    {:reply, :ok, %{state | ip: ip, local_ip: local_ip}, @timeout}
  end

  def handle_info(:timeout, %{registry_server: registry_server, host: host} = state) do
    broadcast_removed(registry_server, host)
    {:stop, :normal, state}
  end

  defp registry_value(ip, local_ip) do
    {inspect(ip), local_ip}
  end

  defp broadcast_updated(registry_server, {_ip, _host, _local_ip} = details) do
    UnregisteredCameraEvents.broadcast(registry_server, {registry_server, :update, details})
  end

  defp broadcast_removed(registry_server, host) do
    UnregisteredCameraEvents.broadcast(registry_server, {registry_server, :removed, host})
  end
end
