defmodule McamServerWeb.CameraLive do
  @moduledoc """
  The main page. See the cameras. Live the life.
  """
  use McamServerWeb, :live_view

  alias McamServer.Cameras
  alias McamServerWeb.EditItemFormComponent

  import McamServerWeb.CameraLiveHelper,
    only: [selected_camera: 2, update_camera: 2, mount_camera: 3]

  def mount(params, session, socket) do
    mount_camera(params, session, socket)
  end

  def handle_params(params, _, socket) do
    camera = selected_camera(params, socket)

    from_camera_id = params["from_camera_id"]

    {:noreply, assign(socket, camera: camera, from_camera_id: from_camera_id)}
  end

  def handle_event("update-camera-name", %{"camera-name" => camera_name}, socket) do
    %{assigns: %{from_camera_id: from_camera_id, camera: camera}} = socket
    Cameras.change_name(camera, camera_name)
    {:noreply, push_patch(socket, to: edit_return_path(socket, from_camera_id))}
  end

  def handle_event("toggle-fullscreen", _, socket) do
    %{assigns: %{camera: camera, live_action: live_action}} = socket

    path =
      case live_action do
        :fullscreen -> Routes.camera_path(socket, :show, camera)
        _ -> Routes.camera_path(socket, :fullscreen, camera)
      end

    {:noreply, redirect(socket, to: path)}
  end

  def handle_info({:camera_name_change, updated}, socket) do
    {camera, all_cameras, guest_cameras} = update_camera(updated, socket)

    {:noreply,
     assign(socket, camera: camera, all_cameras: all_cameras, guest_cameras: guest_cameras)}
  end

  def handle_info({:camera_registration, camera}, socket) do
    %{assigns: %{all_cameras: all_cameras}} = socket
    all_camera_count = length(all_cameras) + 1

    {:noreply,
     assign(socket, all_cameras: all_cameras ++ [camera], all_camera_count: all_camera_count)}
  end

  defp edit_return_path(socket, from_camera_id) do
    Routes.camera_path(socket, :show, from_camera_id)
  end

  def render(%{live_action: :fullscreen} = assigns) do
    ~L"""
    <%= live_component @socket, McamServerWeb.CameraComponent,  camera: @camera, live_action: @live_action %>
    </div>
    """
  end

  def render(assigns) do
    ~L"""
    <%= if @live_action == :edit do %>
      <%= live_modal EditItemFormComponent, camera: @camera, return_to: edit_return_path(@socket, @from_camera_id)  %>
    <% end %>
    <div class="row">
      <div class="column column-70">
            <%= live_component @socket, McamServerWeb.CameraComponent,  camera: @camera, live_action: @live_action %>
      </div>
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
        <div class="row">
          <div class="column">
            <%= live_component @socket, McamServerWeb.InviteAGuestComponent, camera: @camera, user: @user, id: :invite_guest %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
