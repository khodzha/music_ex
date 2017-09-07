defmodule MusicExFrontend.Oauth.Discord do
  @moduledoc """
  An OAuth2 strategy for Discord.
  """
  use OAuth2.Strategy

  alias OAuth2.Strategy.AuthCode

  defp config do
    Application.get_env(:music_ex_frontend, __MODULE__)
  end

  def client(params \\ []) do
    params = Keyword.merge(params, config())
    OAuth2.Client.new(params)
  end

  def authorize_url!(params \\ []) do
    params = Keyword.merge(params, scope: "identify bot")
    OAuth2.Client.authorize_url!(client(), params)
  end

  def get_token!(params \\ [], headers \\ []) do
    OAuth2.Client.get_token!(client(), Keyword.merge(params, client_secret: client().client_secret))
  end

  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end
end
