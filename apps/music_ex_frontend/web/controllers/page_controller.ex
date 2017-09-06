defmodule MusicExFrontend.PageController do
  use MusicExFrontend.Web, :controller

  def index(conn, _params) do
    conn
    |> assign(:current_user, read_private_cookie(conn, "current_user"))
    |> assign(:access_token, read_private_cookie(conn, "access_token"))
    |> render("index.html")
  end
end
