defmodule McamServerWeb.AcceptGuestInvitationLive do
  @moduledoc """
  Accepts the guest invitation.
  """

  use McamServerWeb, :live_view
  alias McamServer.Accounts
  alias McamServer.GuestInvitations

  def mount(%{"invitation_token" => invitation_token}, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    case GuestInvitations.fetch_invitation_details(user, invitation_token) do
      {:ok, {camera_name, owner_email}} ->
        {:ok,
         assign(socket,
           camera_name: camera_name,
           owner_email: owner_email,
           user: user,
           invitation_token: invitation_token
         )}

      {:error, reason} ->
        {:ok, error_redirect(socket, reason)}
    end
  end

  def handle_event("cancel", _, socket) do
    {:noreply, redirect(socket, to: Routes.camera_path(socket, :index))}
  end

  def handle_event("accept", _, socket) do
    %{user: user, invitation_token: token} = socket.assigns

    socket =
      case GuestInvitations.accept_invitation(user, token) do
        {:ok, camera} ->
          socket
          |> put_flash(:info, "Accepted invitation")
          |> redirect(to: Routes.guest_camera_path(socket, :show, camera))

        {:error, reason} ->
          error_redirect(socket, reason)
      end

    {:noreply, socket}
  end

  defp error_redirect(socket, reason) do
    message =
      case reason do
        :own_camera -> "You can not be a guest of your own camera, because that would be silly"
        :already_accepted -> "That invitation had already been accepted"
        :expired -> "That invitation has expired"
        _ -> "That invitation is not valid"
      end

    socket
    |> put_flash(:error, message)
    |> redirect(to: Routes.camera_path(socket, :index))
  end

  def render(assigns) do
    ~L"""
    <h2>Accept this invitation to view a camera</h2>
    <form phx-submit="accept" class="accept-guest-invitation">
      <div class="row">
        <div class="column column-20">
          <span class="info-label">Camera name</span>
        </div>
        <div class="column">
          <span class="info"><%= @camera_name%></span>
        </div>
      </div>
      <div class="row">
        <div class="column column-20">
          <span class="info-label">Owner email</span>
        </div>
        <div class="column">
          <span class="info"><%= @owner_email %></span>
        </div>
      </div>
      <div class="row">
        <div class="column column-20">
          <label for="invitation-token">Token:</label>
        </div>
        <div class="column">
          <input  name="invitation-token" value="<%= @invitation_token %>"></name>
        </div>
      </div>
      <div class="row">
        <div class="column">
          <button type="submit">Accept</button>
          <button phx-click="cancel">Cancel</button>
        </div>
      </div>
    </form>
    """
  end
end
