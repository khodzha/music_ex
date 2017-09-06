defmodule MusicExFrontend.AuthController do
  use MusicExFrontend.Web, :controller

  alias MusicExFrontend.Oauth.Discord

  def index(conn, _params) do
    redirect conn, external: Discord.authorize_url!()
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def callback(conn, %{"code" => code}) do
    client = Discord.get_token!(code: code)

    user = get_user!(client)

    IO.puts(inspect user)

    conn
    |> put_private_cookie("current_user", user["id"], max_age: 86400*5, http_only: true)
    |> put_private_cookie("access_token", client.token.access_token, max_age: 86400*5, http_only: true)
    |> redirect(to: "/")
  end

  defp get_user!(client) do
    %OAuth2.Response{body: user} = OAuth2.Client.get!(client, "/users/@me")

    user
  end
end
