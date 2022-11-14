defmodule McamServerWeb.ImageStreaming.BrowserCommsSocket do
  @moduledoc """
  Image related comms, mostly image streaming, with the browser
  """

  @behaviour Phoenix.Socket.Transport

  alias McamServer.Cameras

  @twenty_minutes 20 * 60 * 1_000
  @token_refresh_period @twenty_minutes

  @impl true
  def child_spec(_opts) do
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl true
  def connect(%{params: %{"token" => token}}) do
    case Cameras.from_token(token, :browser) do
      {:ok, %{id: camera_id}} ->
        {:ok, %{camera_id: camera_id}}

      {:error, :expired} ->
        {:ok, :expired_token}

      _err ->
        :error
    end
  end

  @impl true
  def init(%{camera_id: camera_id} = state) do
    send(self(), :refresh_token)
    Cameras.subscribe_to_camera(camera_id)
    {:ok, state}
  end

  def init(:expired_token) do
    send(self(), :expired_token)
    {:ok, :expired_token}
  end

  @impl true
  def handle_in(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:camera_image, camera_id, image}, %{camera_id: camera_id} = state) do
    {:push, {:binary, image}, state}
  end

  def handle_info(:refresh_token, %{camera_id: camera_id} = state) do
    Process.send_after(self(), :refresh_token, @token_refresh_period)
    token = Cameras.token_for(camera_id, :browser)
    {:push, {:text, "token:" <> token}, state}
  end

  def handle_info(:expired_token, state) do
    send(self(), :close_socket)
    {:push, {:text, "expired_token"}, state}
  end

  def handle_info(:close_socket, state) do
    {:stop, :closed, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _) do
    :ok
  end
end
