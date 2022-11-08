defmodule McamServerWeb.FlashComponent do
  @moduledoc false
  use McamServerWeb, :live_component

  def render(assigns) do
    ~L"""
    <p class="alert alert-info" role="alert"
    phx-click="lv:clear-flash"
    <%= if assigns[:clear_target], do: "phx-target=#{@clear_target}" %>
    phx-value-key="info"><%= live_flash(@flash, :info) %></p>

    <p class="alert alert-danger" role="alert"
    phx-click="lv:clear-flash"
    <%= if assigns[:clear_target], do: "phx-target=#{@clear_target}" %>
    phx-value-key="error"><%= live_flash(@flash, :error) %></p>
    """
  end
end
