defmodule McamServer.CamerasFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `McamServer.Cameras` context.
  """

  alias McamServer.Accounts.User
  alias McamServer.{AccountsFixtures, Cameras, Repo}
  alias McamServer.Cameras.{Camera, GuestCamera}

  def unique_board_id, do: "0000#{System.unique_integer()}"

  def user_camera_fixture(%User{} = user, password \\ nil, camera_attrs \\ %{}) do
    password = password || AccountsFixtures.valid_user_password()
    board_id = camera_attrs[:board_id] || unique_board_id()

    with {:ok, camera} <- Cameras.register(user.email, password, board_id) do
      camera
    end
  end

  def camera_fixture(camera_attrs \\ %{}, user_attrs \\ %{}) do
    password = user_attrs[:password] || AccountsFixtures.valid_user_password()
    user = AccountsFixtures.user_fixture(Map.put(user_attrs, :password, password))
    user_camera_fixture(user, password, camera_attrs)
  end

  def add_guest(%Camera{id: camera_id}, %User{id: guest_id, email: email}) do
    %GuestCamera{}
    |> GuestCamera.changeset(%{
      guest_id: guest_id,
      camera_id: camera_id,
      invitation_expiry: NaiveDateTime.utc_now(),
      invitation_email: email
    })
    |> Repo.insert!()
  end
end
