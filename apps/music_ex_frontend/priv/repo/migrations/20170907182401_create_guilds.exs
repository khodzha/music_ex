defmodule MusicExFrontend.Repo.Migrations.CreateGuilds do
  use Ecto.Migration

  def change do
    create table(:guilds) do
      add :guild_id, :string, null: false
      add :text_channel_id, :string
      add :voice_channel_id, :string

      timestamps()
    end

  end
end
