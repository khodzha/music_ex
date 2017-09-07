defmodule MusicExFrontend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :user_id, :string, null: false
      add :discriminator, :string
      add :username, :string, null: false
      add :avatar, :string

      timestamps()
    end

  end
end
