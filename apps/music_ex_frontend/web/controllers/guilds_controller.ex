defmodule MusicExFrontend.GuildsController do
  use MusicExFrontend.Web, :controller

  alias MusicExFrontend.Oauth.Discord
  alias MusicExDiscord.Discord.API.Guild, as: GuildAPI
  alias MusicExFrontend.Guild
  alias MusicExFrontend.Repo

  def show(conn, %{"id" => gid}) do
    guild_response = GuildAPI.get_guild(gid)
    channels = GuildAPI.get_channels(gid)
    guild = Repo.one(from g in Guild, where: g.guild_id == ^gid)

    conn
    |> assign(:changeset, Guild.changeset(guild))
    |> assign(:guild, guild_response)
    |> assign(:channels, channels)
    |> render("show.html")
  end

  def update(conn, %{"id" => id, "guild" => guild_attrs}) do
    guild = Repo.one(from g in Guild, where: g.guild_id == ^id)

    changes = Guild.changeset(guild, Map.take(guild_attrs, ["text_channel_id", "voice_channel_id"]))
    Repo.update!(changes)

    redirect(conn, to: "/guilds/#{id}")
  end
end
