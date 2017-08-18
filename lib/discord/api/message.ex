defmodule Discord.API.Message do
  alias Discord.API.Url

  @text_channel_id Application.get_env(:music_ex, :text_channel_id)
  def create(body) do
    %HTTPoison.Response{status_code: 200} = HTTPoison.post!(
      "#{Url.base_url()}/channels/#{@text_channel_id}/messages",
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
