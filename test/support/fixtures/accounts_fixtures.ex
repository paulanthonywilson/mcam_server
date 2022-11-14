defmodule McamServer.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `McamServer.Accounts` context.
  """

  alias McamServer.{Accounts, Repo}
  alias Accounts.User

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def user_fixture(attrs \\ %{}) do
    with attrs <-
           Enum.into(valid_user_attributes(attrs), %{confirm?: true}),
         {:ok, user} <- Accounts.register_user(attrs) do
      maybe_confirm(user, attrs)
    end
  end

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_without_subscription(attrs \\ %{}) do
    for _ <- 1..15, do: user_fixture()
    user_fixture(attrs)
  end

  defp maybe_confirm(user, %{confirm?: true}) do
    user
    |> User.confirm_changeset()
    |> Repo.update!()
  end

  defp maybe_confirm(user, _) do
    user
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.text_body, "[TOKEN]")
    token
  end
end
