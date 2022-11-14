defmodule McamServerWeb.UnregisteredCamerasLive do
  @moduledoc """
  Lists unregistered cameras from the same remote IP as the client.
  """
  use McamServerWeb, :live_view

  alias McamServer.UnregisteredCameras

  def mount(_params, %{"remote_ip" => remote_ip}, socket) do
    cameras = UnregisteredCameras.cameras_from_ip(remote_ip)
    :ok = UnregisteredCameras.subscribe()

    {:ok, assign(socket, remote_ip: remote_ip, cameras: cameras)}
  end

  def render(%{cameras: []} = assigns) do
    ~L"""
    <h1>No unregistered cameras from <%= printable_ip(@remote_ip) %></h1>
    """
  end

  def render(assigns) do
    ~L"""
    <h1>Unregistered cameras from <%= printable_ip(@remote_ip) %></h1>
    <p>(seen during in the last minute)</p>
    <ul class="unregistered-cameras">
      <%= for {hostname, local_ip} <- @cameras do %>
        <li id="cam-<%=hostname%>">
          <%= hostname %>:
           <a href="<%= local_camera_url(local_ip) %>"><%= local_camera_url(local_ip) %></a></li>
      <% end %>
    </ul>
    """
  end

  defp local_camera_url(local_ip) do
    "http://#{local_ip}:4000"
  end

  def handle_info({McamServer.UnregisteredCameras, :update, event}, %{assigns: assigns} = socket) do
    handle_incoming_unregistered_camera(event, assigns, socket)
  end

  def handle_info(
        {McamServer.UnregisteredCameras, :removed, removed_host},
        %{assigns: assigns} = socket
      ) do
    cameras =
      assigns
      |> Map.get(:cameras)
      |> Enum.reject(fn {host, _} -> host == removed_host end)

    {:noreply, assign(socket, :cameras, cameras)}
  end

  defp handle_incoming_unregistered_camera(
         {remote_ip, hostname, local_ip},
         %{cameras: cameras, remote_ip: remote_ip},
         socket
       ) do
    {:noreply, assign(socket, :cameras, camera_update(cameras, {hostname, local_ip}))}
  end

  defp handle_incoming_unregistered_camera({_, hostname, _}, %{cameras: cameras}, socket) do
    cameras =
      Enum.filter(cameras, fn
        {^hostname, _} -> false
        _ -> true
      end)

    {:noreply, assign(socket, cameras: cameras)}
  end

  defp camera_update(remaining, details, acc \\ [])

  defp camera_update([], {hostname, local_ip}, acc) do
    [{hostname, local_ip} | Enum.reverse(acc)]
  end

  defp camera_update([{hostname, _} | rest], {hostname, _} = camera, acc) do
    Enum.reverse(acc, [camera | rest])
  end

  defp camera_update([other_cam | rest], camera, acc) do
    camera_update(rest, camera, [other_cam | acc])
  end

  defp printable_ip(remote_ip) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end
end
