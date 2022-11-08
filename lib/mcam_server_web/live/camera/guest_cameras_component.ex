defmodule McamServerWeb.GuestCamerasComponenent do
  @moduledoc """
  Lists the guest cameras
  """
  use McamServerWeb, :live_component

  def render(assigns) do
    ~L"""
    <h2>Guest Cameras</h2>
    <p>Cameras you can view as a guest:</p>
    <ul class="camera-list">
    <%= if [] == @guest_cameras do %>
    <li class="row"><span class="column">None</span></li>
    <% end %>
    <%= for cam <- @guest_cameras do %>
      <li class="row">
      <span class="column">
      <%= if cam == @camera do %>
        <%= cam.name %>
      <% else %>
        <%= live_redirect cam.name, to: Routes.guest_camera_path(@socket, :show, cam.id) %>
      <% end %>
      </span>
      </li>
    <% end %>
    </ul>
    """
  end
end
