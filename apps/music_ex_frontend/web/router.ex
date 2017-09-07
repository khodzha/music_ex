defmodule MusicExFrontend.Router do
  use MusicExFrontend.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MusicExFrontend do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/guilds", GuildsController, only: [:show, :update]
  end

  scope "/auth", MusicExFrontend do
    pipe_through :browser

    get "/", AuthController, :index
    get "/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", MusicExFrontend do
  #   pipe_through :api
  # end
end
