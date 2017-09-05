defmodule MusicExDiscord.Discord.API.Message do
  alias MusicExDiscord.Discord.API.Url

  def create(body) do
    chan_id = Application.get_env(:music_ex_discord, :text_channel_id)

    %HTTPoison.Response{status_code: 200} = HTTPoison.post!(
      "#{Url.base_url()}/channels/#{chan_id}/messages",
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
