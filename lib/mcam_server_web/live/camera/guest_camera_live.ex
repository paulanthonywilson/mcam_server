defmodule McamServerWeb.GuestCameraLive do
  @moduledoc """
  For guest cameras
  """
  use McamServerWeb, :live_view

  import McamServerWeb.CameraLiveHelper, only: [mount_camera: 3, selected_guest_camera: 2]

  def mount(params, session, socket) do
    mount_camera(params, session, socket)
  end

  def handle_params(params, _, socket) do
    camera = selected_guest_camera(params, socket)

    {:noreply, assign(socket, camera: camera)}
  end

  def handle_event("toggle-fullscreen", _, socket) do
    %{assigns: %{camera: camera, live_action: live_action}} = socket

    path =
      case live_action do
        :fullscreen -> Routes.guest_camera_path(socket, :show, camera)
        _ -> Routes.guest_camera_path(socket, :fullscreen, camera)
      end

    {:noreply, redirect(socket, to: path)}
  end

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="column column-70">
            <%= live_component @socket, McamServerWeb.CameraComponent,  camera: @camera, title_prefix: "Guest: ", live_action: @live_action %>
      </div>
      <%= unless @live_action == :fullscreen do %>
      <div class="column-30 camera-side">
        <div class="row">
          <div class="column">
          <%= live_component @socket, McamServerWeb.AllCamerasComponent, all_cameras: @all_cameras,
                                                                         camera: @camera,
                                                                         all_camera_count: @all_camera_count,
                                                                         subscription_plan: @subscription_plan,
                                                                         camera_quota: @camera_quota %>
          </div>
        </div>
        <div class="row">
          <div class="column">
            <%= live_component @socket, McamServerWeb.GuestCamerasComponenent, guest_cameras: @guest_cameras, camera: @camera %>
          </div>
        </div>
      </div>
      <% end %>
    </div>
    """
  end
end
