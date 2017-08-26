defmodule Discord.API.Url do
  @api_version 6
  alias HTTPoison.Response, as: Resp
  alias HTTPoison, as: HTTP

  def get_gateway_url do
    with url <- "#{base_url()}/gateway",
          headers <- ["Authorization": bot_token()],
          {:ok, %Resp{status_code: 200, body: body}} <- HTTP.get(url, headers),
          {:ok, %{"url" => gateway}} <- Poison.decode(body) do
      {:ok, "#{gateway}/?v=#{@api_version}&encoding=json"}
    else
      {_, %Resp{status_code: v}} ->
        {:error, "#{base_url()} returned #{v} code"}
      {_, v} ->
        {:error, v}
    end
  end

  def base_url do
    "https://discordapp.com/api/v#{@api_version}"
  end

  def bot_token do
    "Bot #{Application.fetch_env!(:music_ex, :token)}"
  end
end
