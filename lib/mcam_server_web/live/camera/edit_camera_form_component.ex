defmodule McamServerWeb.EditItemFormComponent do
  @moduledoc """
  Really just about changing camera names
  """
  use McamServerWeb, :live_component

  def render(assigns) do
    ~L"""
    <form phx-submit="update-camera-name">
      <label for="camera-name">Name</label>
      <input name="camera-name" value="<%=@camera.name %>"></input>
      <button type="submit">Change</button>
    </form>
    """
  end
end
