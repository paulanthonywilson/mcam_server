defmodule McamServer.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :camera_quota, :integer, null: false
      add :reference, :string, null: false
      timestamps()
    end

    create unique_index(:subscriptions, :user_id)
  end
end
