defmodule McamServerWeb.CameraComponent do
  @moduledoc """
  Sets up the image for serving camera images in the browser.
  """
  use McamServerWeb, :live_component

  import McamServerWeb.CameraLiveHelper, only: [local_network_url: 1]

  alias McamServer.Cameras

  def render(%{camera: :no_camera} = assigns) do
    ~L"""
    <h2>No camera</h2>
    <p>Instructions for setting up cameras go here.</p>
    """
  end

  def render(assigns) do
    assigns = Map.put_new(assigns, :title_prefix, "")

    ~L"""
    <%= unless @live_action == :fullscreen do %>
    <h2><%= @title_prefix %><%= @camera.name %> </h2>
    <p><a href="<%= local_network_url(@camera) %>">Access on local network</a></p>
    <% end %>
    <img id="cam-image" phx-hook="ImageHook" src="<%= Routes.static_path(@socket, "/images/placeholder.jpeg")  %>"
          <%= if @live_action == :fullscreen, do: "class=fullscreen" %>
         phx-click="toggle-fullscreen"
         data-binary-ws-url="<%= receive_images_websocket_url() %>"
         data-ws-token="<%= token(@camera) %>" ></img>
    <p>Click/touch image to toggle enlarging</p>
    """
  end

  defp receive_images_websocket_url do
    :mcam_server
    |> Application.fetch_env!(:server_ws)
    |> Path.join("raw_ws/browser_interface")
  end

  defp token(camera) do
    Cameras.token_for(camera, :browser)
  end
end
