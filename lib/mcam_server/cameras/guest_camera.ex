defmodule McamServer.Cameras.GuestCamera do
  @moduledoc """
  Links a user to a camera owned by another, so that it may be viewed.

  (Also handles the mechanics of invitations)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias McamServer.Accounts.User
  alias McamServer.Cameras.Camera

  schema "guest_cameras" do
    belongs_to :guest, User
    belongs_to :camera, Camera
    field :invitation_expiry, :naive_datetime
    field :invitation_email, :string

    timestamps()
  end

  @doc false
  def changeset(guest_camera, attrs) do
    guest_camera
    |> cast(attrs, [:guest_id, :camera_id, :invitation_expiry, :invitation_email])
    |> validate_required([:camera_id, :invitation_expiry, :invitation_email])
    |> foreign_key_constraint(:camera_id, name: :guest_cameras_camera_id_fkey)
    |> foreign_key_constraint(:guest_id, name: :guest_cameras_guest_id_fkey)
  end
end
