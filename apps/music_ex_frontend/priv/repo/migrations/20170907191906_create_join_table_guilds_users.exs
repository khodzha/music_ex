defmodule MusicExFrontend.Repo.Migrations.CreateJoinTableGuildsUsers do
  use Ecto.Migration

  def change do
    create table(:guilds_users) do
      add :guild_id, references("guilds"), null: false
      add :user_id, references("users"), null: false
    end

    create index("guilds_users", [:guild_id, :user_id], unique: true)
  end
end
