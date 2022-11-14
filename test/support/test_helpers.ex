defmodule TestHelpers do
  @moduledoc false

  def wait_until_equals(expected, actual_fn, attempt_count \\ 100)
  def wait_until_equals(_expected, actual_fn, 0), do: actual_fn.()

  def wait_until_equals(expected, actual_fn, attempt_count) do
    case actual_fn.() do
      ^expected ->
        expected

      _ ->
        :timer.sleep(1)
        wait_until_equals(expected, actual_fn, attempt_count - 1)
    end
  end
end
