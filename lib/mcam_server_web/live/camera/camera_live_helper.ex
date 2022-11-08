defmodule McamServerWeb.CameraLiveHelper do
  @moduledoc """
  Helper functions for `McamServerWeb.CameraLive`
  """

  import Phoenix.LiveView.Utils, only: [assign: 3]

  alias McamServer.{Accounts, Cameras, Cameras.Camera, Subscriptions}
  alias Phoenix.LiveView.Socket

  @doc """
  Extract the camera from the list of `:all_cameras` assigned in the socket, using the "camera_id"
  (String key) set in the params. If there is no camera id in the params, or it is not found,
  returns the first camera.

  `:no_camera` is returned if the `:all_cameras` list is empty.
  """
  @spec selected_camera(map(), Socket.t()) :: Camera.t() | :no_camera
  def selected_camera(%{"camera_id" => camera_id}, socket) when is_binary(camera_id) do
    selected_camera(%{"camera_id" => String.to_integer(camera_id)}, socket)
  end

  def selected_camera(params, %{assigns: %{all_cameras: own_cameras}}) do
    case do_selected_camera(params, own_cameras) do
      nil -> :no_camera
      camera -> camera
    end
  end

  defp do_selected_camera(_, []), do: nil

  defp do_selected_camera(%{"camera_id" => camera_id}, [default | _] = cameras) do
    Enum.find(cameras, default, fn %{id: id} -> id == camera_id end)
  end

  defp do_selected_camera(_, [first | _]), do: first

  @doc """
  Similar to `selected_camera/2`, except that the list of guest cameras assgigned (`:guest_cameras` key) to
  the socket is used instead of `:all_cameras`.

  If the id is invalid then `:no_camera` is returned - not the first guest camera.
  """
  @spec selected_guest_camera(map(), Socket.t()) :: Camera.t() | :no_camera
  def selected_guest_camera(%{"camera_id" => camera_id}, socket) when is_binary(camera_id) do
    selected_guest_camera(%{"camera_id" => String.to_integer(camera_id)}, socket)
  rescue
    ArgumentError ->
      :no_camera
  end

  def selected_guest_camera(%{"camera_id" => camera_id}, %{
        assigns: %{guest_cameras: guest_cameras}
      }) do
    Enum.find(guest_cameras, :no_camera, fn %{id: id} -> id == camera_id end)
  end

  def selected_guest_camera(_, _), do: :no_camera

  @doc """
  Handles a camera update, using the socket assigns to retur a tuple containing

  * first element - the assigned `:camera`. This is replaced with the update if the id matches, reflecting the update.
  * second element - the last of `:all_cameras`, replacing one with the update if it the id maatches
  * third element - the list of `:guest_cameras`, replacing one with the update if the id matches
  """
  @spec update_camera(Camera.t(), Socket.t()) :: {Camera.t(), list(Camera.t()), list(Camera.t())}
  def update_camera(
        %{id: updated_id} = updated_camera,
        %{assigns: %{camera: camera, all_cameras: all_cameras, guest_cameras: guest_cameras}}
      ) do
    camera =
      case camera do
        %{id: ^updated_id} -> updated_camera
        _ -> camera
      end

    all_cameras = do_update_camera(updated_camera, [], all_cameras)
    guest_cameras = do_update_camera(updated_camera, [], guest_cameras)

    {camera, all_cameras, guest_cameras}
  end

  defp do_update_camera(%{id: id} = updated, acc, [%{id: id} | rest]) do
    Enum.reverse([updated | acc], rest)
  end

  defp do_update_camera(updated, acc, [camera | rest]) do
    do_update_camera(updated, [camera | acc], rest)
  end

  defp do_update_camera(_, acc, []), do: Enum.reverse(acc)

  @doc """
  Very basic email validation, checking presence of a some characters then `a` then taking
  some liberties and requiring at least a domain and a tld.

  """
  @spec basic_email_validate(String.t()) :: :bad_email | :ok
  def basic_email_validate(alleged_email) do
    if alleged_email =~ ~r/.+@.+\..+/, do: :ok, else: :bad_email
  end

  @doc """
  The common parts of a LiveView mount for a camera:
  * Gets the user using the session token
  * Gets all the user's cameras
  * Gets all the guest cameras for the user
  * Subscribes to new camera registrations, so that
  * Subscribes to name change updates for all the above cameras
  * Assigns `:user`, `:all_cmeras`, and `:guest_cameras`
  """
  @spec mount_camera(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount_camera(_params, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)
    all_cameras = Cameras.user_cameras(user)
    guest_cameras = Cameras.guest_cameras(user)
    {subscription_plan, camera_quota} = Subscriptions.camera_quota(user)
    Cameras.subscribe_to_registrations(user)

    for cam <- all_cameras ++ guest_cameras, do: Cameras.subscribe_to_name_change(cam)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:camera_quota, camera_quota)
     |> assign(:subscription_plan, subscription_plan)
     |> assign(:all_cameras, all_cameras)
     |> assign(:all_camera_count, length(all_cameras))
     |> assign(:guest_cameras, guest_cameras)}
  end

  def local_network_url(%{board_id: board_id}), do: local_network_url(board_id)

  def local_network_url(board_id) do
    board_id
    |> String.slice(-4..-1)
    |> prepend("nerves-")
    |> hostname_to_nerves_local_url()
  end

  defp prepend(str, pre), do: pre <> str
  defp hostname_to_nerves_local_url(name), do: "http://#{name}.local:4000"
end
