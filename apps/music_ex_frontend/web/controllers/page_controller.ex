defmodule MusicExFrontend.PageController do
  use MusicExFrontend.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
