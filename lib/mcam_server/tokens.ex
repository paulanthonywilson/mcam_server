defmodule McamServer.Tokens do
  @moduledoc """
  Deals with teh tokenz.
  """

  alias Plug.Crypto

  @four_weeks 60 * 60 * 24 * 7 * 4
  @four_days 60 * 60 * 24 * 4
  @one_hour 60 * 60

  @type token_target :: :camera | :browser | :guest_invitation

  defguard valid_token_target(destination)
           when destination in [:camera, :browser, :guest_invitation]

  @spec to_token(term(), token_target(), keyword()) :: binary()
  def to_token(term, token_target, opts \\ []) when valid_token_target(token_target) do
    Crypto.encrypt(secret(token_target), salt(token_target), term, opts)
  end

  @spec from_token(binary(), token_target()) ::
          {:ok, term()} | {:error, :expired | :invalid | :missing}
  def from_token(token, token_target) when valid_token_target(token_target) do
    Crypto.decrypt(secret(token_target), salt(token_target), token, max_age: max_age(token_target))
  end

  defp secret(token_target), do: token_config(token_target, :secret)
  defp salt(token_target), do: token_config(token_target, :salt)

  defp token_config(token_target, key) do
    token_target
    |> token_env()
    |> Keyword.fetch!(key)
  end

  defp token_env(:camera), do: Application.fetch_env!(:mcam_server, :camera_token)
  defp token_env(:browser), do: Application.fetch_env!(:mcam_server, :browser_token)
  defp token_env(:guest_invitation), do: Application.fetch_env!(:mcam_server, :browser_token)

  @doc """
  The maximum agen in seconds for the token type
  """
  @spec max_age(:browser | :camera | :guest_invitation) :: pos_integer()
  def max_age(:camera), do: @four_weeks
  def max_age(:browser), do: @one_hour
  def max_age(:guest_invitation), do: @four_days
end
