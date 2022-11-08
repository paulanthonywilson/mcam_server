defmodule McamServerWeb.LiveHelpers do
  @moduledoc false
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `McamServerWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal @socket, McamServerWeb.PenguinLive.FormComponent,
        id: @penguin.id || :new,
        action: @live_action,
        penguin: @penguin,
        return_to: Routes.penguin_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(nil, McamServerWeb.ModalComponent, modal_opts)
  end
end
