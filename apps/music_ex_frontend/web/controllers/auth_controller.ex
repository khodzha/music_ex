defmodule MusicExFrontend.AuthController do
  use MusicExFrontend.Web, :controller

  alias MusicExFrontend.Oauth.Discord
  alias MusicExFrontend.User
  alias MusicExFrontend.Guild

  import Ecto.Query, only: [from: 2]

  def index(conn, _params) do
    redirect conn, external: Discord.authorize_url!()
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def callback(conn, %{"code" => code, "guild_id" => guild_id}) do
    client = Discord.get_token!(code: code)

    user = get_user!(client)
    guild = case Repo.one(from g in Guild, where: g.guild_id == ^guild_id) do
      nil ->
        Repo.insert!(Guild.changeset(%Guild{}, %{guild_id: guild_id}))
      guild ->
        Repo.update!(Guild.changeset(guild, %{guild_id: guild_id}))
    end

    guild
    |> Repo.preload(:users)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:users, [user])
    |> Repo.update!()


    conn
    |> put_private_cookie("current_user", user.id, max_age: 86400*5, http_only: true)
    |> redirect(to: "/guilds/#{guild.guild_id}")
  end

  defp get_user!(client) do
    %OAuth2.Response{body: userdata} = OAuth2.Client.get!(client, "/users/@me")

    attrs = userdata
    |> Map.take(["avatar", "discriminator", "username"])
    |> Map.put("user_id", userdata["id"])

    {:ok, user} = User.update_or_create(attrs)

    user
  end
end
