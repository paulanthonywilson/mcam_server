defmodule McamServerWeb.AllCamerasComponent do
  @moduledoc """
  Component for listing a user's cameras, and selecting the camera to view.camera
  """
  use McamServerWeb, :live_component

  def render(assigns) do
    ~L"""
    <h2>Your Cameras</h2>
    <ul class="camera-list">
    <%= for cam <- @all_cameras do %>
      <li class="row">
      <span class="column">
      <%= if cam == @camera do %>
        <%= cam.name %>
      <% else %>
        <%= live_redirect cam.name, to: Routes.camera_path(@socket, :show, cam.id) %>
      <% end %>
      </span>
      <span class="column">
      <%= link "Edit", [to: Routes.camera_path(@socket, :edit, cam.id, @camera.id), class: "button button-clear"] %>
      </span>
      </li>
    <% end %>
    </ul>
    <p><%=  "#{@all_camera_count} out of #{@camera_quota} with #{@subscription_plan} plan" %></p>
    """
  end
end
