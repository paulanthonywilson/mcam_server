defmodule McamServer.GuestInvitations do
  @moduledoc """
  Helps camera owners invite guests to share a camera.

  Invitations are sent via email, but the invitation is not linked to the email.

  Consequences:

  * The guest can accept with their registered/preferred email, rather than the one that
  was sent
  * We do not need to deal with the awkward process of connecting invitations to emails that were
  not registered at the time of invitation
  * On the downside, an invitation could be hijacked by an intercepted email
  """

  import Ecto.Query

  alias McamServer.Accounts.User
  alias McamServer.Cameras.{Camera, GuestCamera}
  alias McamServer.Mailer
  alias McamServer.{Repo, Tokens}

  @token_max_age_seconds Tokens.max_age(:guest_invitation)

  @type accept_error ::
          {:error, :already_accepted | :expired | :invalid | :missing | :not_found | :own_camera}

  @doc """
  Sends an email with an invitation. The token is also returned for no good reason.

  The `accept_url_function` is used to generate a url to accept the invitation.
  """
  @spec invite_a_guest(Camera.t(), String.t(), function()) ::
          {:ok, binary()} | {:error, :not_found}
  def invite_a_guest(%Camera{id: camera_id} = camera, invitation_email, accept_url_function) do
    with {:ok, %GuestCamera{id: guest_id}} <- do_invite(camera_id, invitation_email) do
      token = Tokens.to_token(guest_id, :guest_invitation)
      send_guest_invitation(camera, invitation_email, token, accept_url_function)
      {:ok, token}
    end
  end

  def invite_a_guest(nil, _, _), do: {:error, :not_found}

  def invite_a_guest(camera_id, invitation_email, accept_url_function) do
    Camera
    |> Repo.get(camera_id)
    |> invite_a_guest(invitation_email, accept_url_function)
  end

  @doc """
  Accepts an invitation.
  """
  @spec accept_invitation(User.t(), binary) :: {:ok, Camera.t()} | accept_error()
  def accept_invitation(%User{id: guest_id}, token) do
    accept_invitation(guest_id, token)
  end

  def accept_invitation(guest_id, token) do
    with {:ok, guest_camera_id} <- Tokens.from_token(token, :guest_invitation),
         {guest_camera, camera} <- guest_camera_with_camera(guest_camera_id),
         {:ok, _} <- do_accept(guest_id, camera, guest_camera) do
      {:ok, camera}
    end
  end

  defp do_accept(_, _, %GuestCamera{guest_id: guest_id}) when not is_nil(guest_id) do
    {:error, :already_accepted}
  end

  defp do_accept(guest_id, %{owner_id: guest_id}, _), do: {:error, :own_camera}

  defp do_accept(guest_id, _, guest_camera) do
    guest_camera
    |> GuestCamera.changeset(%{guest_id: guest_id})
    |> Repo.update()
  end

  @doc """
  Fetch the basic invitation details. The invitations needs not to have been accepted.

  On success returns `:ok` with a tuple containing the name of the camera and the owner's
  email.
  """
  @spec fetch_invitation_details(User.t(), binary) ::
          {:ok, {String.t(), String.t()}} | accept_error()
  def fetch_invitation_details(%User{id: guest_id}, token) do
    with {:ok, camera_id} <- Tokens.from_token(token, :guest_invitation),
         {:ok, _} = result <- do_invitation_details(guest_id, camera_id) do
      result
    end
  end

  defp do_invitation_details(guest_id, camera_id) do
    q =
      from g in GuestCamera,
        where: g.id == ^camera_id,
        join: c in Camera,
        on: c.id == g.camera_id,
        join: u in User,
        where: u.id == c.owner_id,
        select: {g.guest_id, c.name, u.email, c.owner_id}

    case Repo.one(q) do
      {_, _, _, ^guest_id} -> {:error, :own_camera}
      {nil, camera_name, owner_email, _} -> {:ok, {camera_name, owner_email}}
      nil -> {:error, :not_found}
      _ -> {:error, :already_accepted}
    end
  end

  defp guest_camera_with_camera(guest_camera_id) do
    case Repo.all(
           from g in GuestCamera,
             join: c in Camera,
             on: c.id == g.camera_id,
             where: g.id == ^guest_camera_id,
             select: {g, c}
         ) do
      [result] -> result
      [] -> :not_found
    end
  end

  defp do_invite(camera_id, invitation_email) do
    %GuestCamera{}
    |> GuestCamera.changeset(%{
      camera_id: camera_id,
      invitation_expiry: invitation_expiry(),
      invitation_email: invitation_email
    })
    |> Repo.insert()
  end

  defp invitation_expiry do
    NaiveDateTime.add(NaiveDateTime.utc_now(), @token_max_age_seconds)
  end

  defp send_guest_invitation(camera, invitation_email, token, accept_token_url_f) do
    camera = Repo.preload(camera, :owner)
    subject = "You have been invited to view a Mere Cam"

    body = """
    Hi,

    #{camera.owner.email} has invited you to view a Mere Cam. You can acccept the invitation by following the link below.

    #{accept_token_url_f.(token)}

    The entire link is needed - be careful that your email reader has not split it across lines. The link will expire in four days.

    You may need to log in / register. You do not need to use this address as your username.

    💚💚💚
    --
    The Mere Cams
    """

    Mailer.send_email(invitation_email, subject, body)
  end
end
