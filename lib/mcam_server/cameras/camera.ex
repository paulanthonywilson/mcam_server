defmodule McamServer.Cameras.Camera do
  @moduledoc """
  Represents a Pi camera. The board id and owner email define the camera. The same board id
  registered with a different owner email is considered a new camera.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias McamServer.Accounts.User

  @type t :: %__MODULE__{}

  schema "cameras" do
    field :board_id, :string
    belongs_to :owner, User
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(camera, attrs) do
    camera
    |> cast(attrs, [:board_id, :name])
    |> validate_required([:board_id, :name])
    |> unique_constraint([:owner_id, :board_id], name: :cameras_board_id_owner_id_index)
  end
end
