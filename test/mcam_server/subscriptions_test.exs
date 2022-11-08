defmodule McamServer.SubscriptionsTest do
  use McamServer.DataCase

  alias McamServer.Subscriptions
  alias McamServer.Subscriptions.Subscription
  import McamServer.AccountsFixtures

  test "a user without a subscription has zero camera quota" do
    assert Subscriptions.camera_quota(user_without_subscription()) == {:none, 0}
  end

  test "a user with an alpha subscription has a 3 camera quota" do
    user = user_fixture()
    Subscriptions.set_subscription(user, :alpha)
    assert Subscriptions.camera_quota(user) == {:alpha, 20}
  end

  test "updating a subscription" do
    user = user_without_subscription()

    Repo.insert!(%Subscription{user_id: user.id, reference: "epsilon", camera_quota: 120})

    Subscriptions.set_subscription(user, :alpha)
    assert Subscriptions.camera_quota(user) == {:alpha, 20}
  end
end
