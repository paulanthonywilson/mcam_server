defmodule McamServerWeb.InviteAGuestComponent do
  @moduledoc """
  Component for inviting a guest to view the camera.
  """
  use McamServerWeb, :live_component

  import McamServerWeb.CameraLiveHelper, only: [basic_email_validate: 1]
  alias McamServer.GuestInvitations

  def mount(socket) do
    {:ok, assign(socket, guest_email: "")}
  end

  def render(assigns) do
    ~H"""
    <div>
    <h2>Invite a guest</h2>
    <p>Invite someone to view the current camera. </p>
    <%= live_component McamServerWeb.FlashComponent, flash: @flash, clear_target: @myself %>
    <form phx-submit="invite-a-guest" phx-target={@myself} phx-change="email-change">
    <label for="guest-email">Guest email</label>
    <input name="guest-email" type="email" value={@guest_email}/>
    <input type="submit" value="invite"/>
    </form>
    </div>
    """
  end

  def handle_event("invite-a-guest", %{"guest-email" => email}, socket) do
    %{camera: camera} = socket.assigns
    socket = clear_flash(socket)

    socket =
      with :ok <- basic_email_validate(email),
           :ok <- invite_guest(camera, email, socket) do
        socket
        |> assign(:guest_email, "")
        |> put_flash(:info, "#{email} invited")
      else
        :bad_email -> put_flash(socket, :error, "I can not accept that is a real email")
        _ -> put_flash(socket, :error, "Sorry. Something bad happened.")
      end

    {:noreply, socket}
  end

  def handle_event("email-change", %{"guest-email" => email}, socket) do
    {:noreply, assign(socket, guest_email: email)}
  end

  defp invite_guest(camera, email, socket) do
    with {:ok, _} <-
           GuestInvitations.invite_a_guest(
             camera,
             email,
             &Routes.accept_guest_invitation_url(socket, :new, &1)
           ) do
      :ok
    end
  end
end
