defmodule McamServer.Repo.Migrations.CreateGuestCameras do
  use Ecto.Migration

  def change do
    create table(:guest_cameras) do
      add :guest_id, references(:users, on_delete: :nothing)
      add :camera_id, references(:cameras, on_delete: :nothing)
      add :invitation_expiry, :naive_datetime
      add :invitation_email, :string
      timestamps()
    end

    create index(:guest_cameras, [:guest_id])
    create index(:guest_cameras, [:camera_id])
  end
end
