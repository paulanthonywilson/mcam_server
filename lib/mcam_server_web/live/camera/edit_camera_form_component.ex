defmodule McamServerWeb.EditItemFormComponent do
  @moduledoc """
  Really just about changing camera names
  """
  use McamServerWeb, :live_component

  def render(assigns) do
    ~H"""
    <form phx-submit="update-camera-name">
      <label for="camera-name">Name</label>
      <input name="camera-name" value={@camera.name}/>
      <button type="submit">Change</button>
    </form>
    """
  end
end
