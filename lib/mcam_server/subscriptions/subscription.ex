defmodule McamServer.Subscriptions.Subscription do
  @moduledoc """
  Represents a simple "subscription" limiting the number of cameras
  a user can register. Potentially could link to a recurring bill.


  """
  use Ecto.Schema
  import Ecto.Changeset

  alias McamServer.Accounts.User

  @type t :: %__MODULE__{}

  schema "subscriptions" do
    belongs_to :user, User
    field :camera_quota, :integer
    field :reference, :string
    timestamps()
  end

  @fields [:camera_quota, :reference, :user_id]

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:user_id)
  end
end
