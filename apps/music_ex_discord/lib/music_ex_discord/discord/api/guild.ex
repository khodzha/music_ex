defmodule MusicExDiscord.Discord.API.Guild do
  alias MusicExDiscord.Discord.API.Url

  def get_guild(guild_id) do
    request("/guilds/#{guild_id}")
  end

  def get_channels(guild_id) do
    request("/guilds/#{guild_id}/channels")
  end

  defp request(url) do
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(
      Url.base_url() <> url,
      [
        "Content-Type": "application/json",
        "Authorization": Url.bot_token()
      ]
    )

    Poison.decode!(body)
  end
end
