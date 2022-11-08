defmodule McamServer.Cameras do
  @moduledoc """
  The Cameras context.
  """

  import Ecto.Query, warn: false

  alias McamServer.{Accounts, Repo}
  alias McamServer.Accounts.User
  alias McamServer.Cameras.{Camera, GuestCamera}
  alias McamServer.Subscriptions
  alias McamServer.Tokens
  alias Phoenix.PubSub

  @pubsub McamServer.PubSub

  @doc """
  Registers a camera to a a user
  """
  @spec register(String.t(), String.t(), String.t()) ::
          {:ok, Camera.t()} | {:error, :authentication_failure} | {:error, Ecto.Changeset.t()}
  def register(owner_email, owner_password, board_id) do
    with {:user, %{id: user_id}} <-
           {:user, Accounts.get_user_by_email_and_password(owner_email, owner_password)},
         owned_already <- owned_camera_count(user_id),
         {_, quota} = Subscriptions.camera_quota(user_id),
         {:quota, true} <- {:quota, owned_already < quota} do
      %Camera{owner_id: user_id}
      |> Camera.changeset(%{board_id: board_id, name: board_id})
      |> Repo.insert()
      |> maybe_broadcast_registration()
      |> maybe_retrieve_original_if_duplicate({user_id, board_id})
    else
      {:user, _} ->
        {:error, :authentication_failure}

      {:quota, _} ->
        {:error, :quota_exceeded}
    end
  end

  defp owned_camera_count(user_id) do
    Repo.one(from c in Camera, where: c.owner_id == ^user_id, select: count(c.id))
  end

  defp maybe_retrieve_original_if_duplicate({:ok, _} = res, _), do: res

  defp maybe_retrieve_original_if_duplicate(
         {:error, %{errors: errors}} = res,
         {owner_id, board_id}
       ) do
    case Keyword.get(errors, :owner_id) do
      {_, [constraint: :unique, constraint_name: "cameras_board_id_owner_id_index"]} ->
        {:ok,
         Repo.one!(from c in Camera, where: c.owner_id == ^owner_id and c.board_id == ^board_id)}

      _ ->
        res
    end
  end

  defp maybe_broadcast_registration({:ok, %{owner_id: owner_id} = camera} = res) do
    PubSub.broadcast!(@pubsub, registration_topic(owner_id), {:camera_registration, camera})
    res
  end

  defp maybe_broadcast_registration(res), do: res

  @spec token_for(Camera.t() | integer(), Tokens.token_target()) :: String.t()
  def token_for(%Camera{id: id}, token_target) do
    token_for(id, token_target)
  end

  def token_for(camera_id, token_target) do
    Tokens.to_token(camera_id, token_target)
  end

  @spec from_token(String.t(), Tokens.token_target()) ::
          {:ok, Camera.t()} | {:error, :expired | :invalid | :missing | :not_found}
  def from_token(token, token_target) do
    with {:ok, id} <- Tokens.from_token(token, token_target),
         {:camera, camera} when not is_nil(camera) <- {:camera, Repo.get(Camera, id)} do
      {:ok, camera}
    else
      {:camera, nil} -> {:error, :not_found}
      err -> err
    end
  end

  @spec subscribe_to_camera(any) :: :ok
  def subscribe_to_camera(camera_id) do
    PubSub.subscribe(@pubsub, camera_topic(camera_id))
  end

  def broadcast_image(camera_id, image) do
    PubSub.broadcast!(@pubsub, camera_topic(camera_id), {:camera_image, camera_id, image})
  end

  @spec subscribe_to_registrations(User.t() | integer()) ::
          :ok | {:error, {:already_registered, pid}}
  def subscribe_to_registrations(%{id: user_id}) do
    subscribe_to_registrations(user_id)
  end

  def subscribe_to_registrations(user_id) do
    PubSub.subscribe(@pubsub, registration_topic(user_id))
  end

  def subscribe_to_name_change(%Camera{id: id}) do
    subscribe_to_name_change(id)
  end

  def subscribe_to_name_change(id) do
    PubSub.subscribe(@pubsub, name_change_topic(id))
  end

  def user_cameras(%{id: user_id}) do
    user_cameras(user_id)
  end

  def user_cameras(user_id) do
    Repo.all(from c in Camera, where: c.owner_id == ^user_id)
  end

  def guest_cameras(%{id: user_id}) do
    Repo.all(
      from c in Camera,
        join: g in GuestCamera,
        on: c.id == g.camera_id,
        where: g.guest_id == ^user_id
    )
  end

  def guest_cameras(user_id) do
    Repo.all(from c in Camera, where: c.owner_id == ^user_id)
  end

  def change_name(camera, name) do
    camera
    |> Camera.changeset(%{name: name})
    |> Repo.update()
    |> maybe_broadcast_name_change()
  end

  defp maybe_broadcast_name_change({:ok, %{id: id} = camera} = res) do
    PubSub.broadcast(@pubsub, name_change_topic(id), {:camera_name_change, camera})
    res
  end

  defp maybe_broadcast_name_change(res), do: res

  defp camera_topic(camera_id), do: "camera:#{camera_id}"
  defp registration_topic(user_id), do: "camera_registrations:#{user_id}"
  defp name_change_topic(camera_id), do: "camera:name_change:#{camera_id}"
end
