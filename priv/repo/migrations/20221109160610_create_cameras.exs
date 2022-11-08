defmodule McamServer.Repo.Migrations.CreateCameras do
  use Ecto.Migration

  def change do
    create table(:cameras) do
      add :board_id, :string
      add :owner_id, references(:users, on_delete: :delete_all)
      add :name, :string

      timestamps()
    end

    create index(:cameras, [:owner_id])
    create index(:cameras, [:board_id, :owner_id], unique: true)
  end
end
