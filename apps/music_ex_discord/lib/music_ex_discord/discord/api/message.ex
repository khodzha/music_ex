defmodule MusicExDiscord.Discord.API.Message do
  alias MusicExDiscord.Discord.API.Url

  def create(channel_id, body) do
    %HTTPoison.Response{status_code: 200} = HTTPoison.post!(
      "#{Url.base_url()}/channels/#{channel_id}/messages",
      Poison.encode!(%{
        content: body
      }),
      [
        "Content-Type": "application/json",
        "Authorization": Url.bot_token()
      ]
    )
  end
end
