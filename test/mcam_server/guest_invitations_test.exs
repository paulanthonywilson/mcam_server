defmodule McamServer.GuestInvitationsTest do
  use McamServer.DataCase, async: true

  import McamServer.AccountsFixtures
  import McamServer.CamerasFixtures

  alias McamServer.Cameras.{Camera, GuestCamera}
  alias McamServer.{GuestInvitations, Repo, Tokens}

  @an_email "somemail@example.com"

  defp token_url_f, do: fn token -> "https://example.com/accept/#{token}" end

  setup do
    owner = user_fixture()
    guest = user_fixture()
    camera = user_camera_fixture(owner)
    {:ok, owner: owner, guest: guest, camera: camera}
  end

  describe "creating an invitation" do
    test "creates a guest camera without a guest id", %{camera: %{id: camera_id} = camera} do
      assert {:ok, _token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())

      assert %GuestCamera{guest_id: nil, camera_id: ^camera_id, invitation_email: @an_email} =
               Repo.one(GuestCamera)
    end

    test "invitation expiry is in about 4 days", %{camera: camera} do
      {:ok, _token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      %{invitation_expiry: expiry} = Repo.one(GuestCamera)

      should_be_about_now = NaiveDateTime.add(expiry, -Tokens.max_age(:guest_invitation))
      assert abs(NaiveDateTime.diff(NaiveDateTime.utc_now(), should_be_about_now)) < 10
    end

    test "bad camera id returns an error" do
      assert {:error, :not_found} = GuestInvitations.invite_a_guest(-1, @an_email, token_url_f())
    end

    test "email sent to the invited guest", %{camera: camera, owner: %{email: owner_email}} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      assert_receive {:email, %{subject: subject, text_body: body, to: to}}

      assert subject =~ "invited"
      assert [{_, @an_email}] = to
      assert body =~ token_url_f().(token)
      assert body =~ owner_email
    end
  end

  describe "accepting an invitation" do
    test "with valid token is successful", %{
      camera: %{id: camera_id},
      guest: %{id: guest_id} = guest
    } do
      {:ok, token} = GuestInvitations.invite_a_guest(camera_id, @an_email, token_url_f())
      assert {:ok, %Camera{id: ^camera_id}} = GuestInvitations.accept_invitation(guest, token)
      assert %GuestCamera{guest_id: ^guest_id, camera_id: ^camera_id} = Repo.one(GuestCamera)
    end

    test "correct invitation is accepted", %{
      camera: %{id: camera_id},
      guest: %{id: guest_id} = guest
    } do
      {:ok, token} = GuestInvitations.invite_a_guest(camera_id, @an_email, token_url_f())
      %{id: guest_camera_id} = Repo.one(GuestCamera)

      {:ok, _} =
        GuestInvitations.invite_a_guest(camera_id, "someotheremail@blah.com", token_url_f())

      {:ok, _} = GuestInvitations.accept_invitation(guest, token)

      assert %GuestCamera{guest_id: ^guest_id, camera_id: ^camera_id} =
               Repo.get(GuestCamera, guest_camera_id)
    end

    test "when guest camera is no longer valid", %{camera: camera, guest: guest} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      Repo.delete_all(GuestCamera)
      assert :not_found == GuestInvitations.accept_invitation(guest, token)
    end

    test "when guest is not valid", %{camera: camera} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())

      assert {:error, _} = GuestInvitations.accept_invitation(-1, token)
    end

    test "with invalid token", %{guest: guest} do
      assert {:error, :invalid} == GuestInvitations.accept_invitation(guest, "this is nonsense")
    end

    test "with expired token", %{guest: guest, camera: camera} do
      token = expired_token(camera)
      assert {:error, :expired} == GuestInvitations.accept_invitation(guest, token)
    end

    test "when the invitation has aleady been accepted", %{guest: guest, camera: camera} do
      other_guest = user_fixture()
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      {:ok, _} = GuestInvitations.accept_invitation(other_guest, token)

      assert {:error, :already_accepted} = GuestInvitations.accept_invitation(guest, token)
    end

    test "you can not be a guest at your own party", %{owner: owner, camera: camera} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      assert {:error, :own_camera} = GuestInvitations.accept_invitation(owner, token)
    end
  end

  describe "fetching invitation details" do
    test "when the invitation is valid", %{
      camera: %{name: camera_name} = camera,
      owner: %{email: owner_email},
      guest: guest
    } do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())

      assert {:ok, {^camera_name, ^owner_email}} =
               GuestInvitations.fetch_invitation_details(guest, token)
    end

    test "when the token is nonsense", %{guest: guest} do
      assert {:error, :invalid} == GuestInvitations.fetch_invitation_details(guest, "forecastle")
    end

    test "when the token has expired", %{camera: camera, guest: guest} do
      token = expired_token(camera)
      assert {:error, :expired} == GuestInvitations.fetch_invitation_details(guest, token)
    end

    test "when guest camera is no longer valid", %{camera: camera, guest: guest} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      Repo.delete_all(GuestCamera)
      assert {:error, :not_found} == GuestInvitations.fetch_invitation_details(guest, token)
    end

    test "when the invitation has aleady been accepted", %{guest: guest, camera: camera} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      {:ok, _} = GuestInvitations.accept_invitation(guest, token)

      assert {:error, :already_accepted} = GuestInvitations.fetch_invitation_details(guest, token)
    end

    test "when the guest is the owner", %{owner: owner, camera: camera} do
      {:ok, token} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
      assert {:error, :own_camera} == GuestInvitations.fetch_invitation_details(owner, token)
    end
  end

  defp expired_token(camera) do
    {:ok, _} = GuestInvitations.invite_a_guest(camera, @an_email, token_url_f())
    %{id: guest_camera_id} = Repo.one(GuestCamera)
    Tokens.to_token(guest_camera_id, :guest_invitation, signed_at: 0)
  end
end
