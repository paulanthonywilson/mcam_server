defmodule McamServerWeb.ImageStreaming.CameraCommsSocket do
  @moduledoc """
  Socket that communicates with "cameras" (Pi Zeros).
  """

  @behaviour Phoenix.Socket.Transport
  require Logger

  alias McamServer.Cameras

  @acknowledge_image_receipt "\n"

  @ten_minutes 10 * 60 * 1_000
  @token_refresh_period @ten_minutes

  def child_spec(_opts) do
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: %{"token" => token}}) do
    case Cameras.from_token(token, :camera) do
      {:ok, %{id: camera_id}} ->
        Logger.debug(fn -> "Connection from camera #{camera_id}" end)
        {:ok, %{camera_id: camera_id}}

      err ->
        Logger.info(fn -> "Invalid camera connection request #{inspect(err)}" end)
        :error
    end
  end

  def init(state) do
    send(self(), :refresh_token)
    {:ok, state}
  end

  def handle_in({image, [opcode: :binary]}, %{camera_id: camera_id} = state) do
    Cameras.broadcast_image(camera_id, image)
    {:reply, :ok, {:binary, @acknowledge_image_receipt}, state}
  end

  def handle_info(:refresh_token, %{camera_id: camera_id} = state) do
    Process.send_after(self(), :refresh_token, @token_refresh_period)
    refreshed_token = Cameras.token_for(camera_id, :camera)
    message = :erlang.term_to_binary({:token_refresh, refreshed_token})
    {:push, {:binary, message}, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
