defmodule MusicExFrontend.GuildsView do
  use MusicExFrontend.Web, :view

  @guild_text 0
  @guild_voice 2
  def guild_icon(guild, size \\ 64) do
    "https://cdn.discordapp.com/icons/#{guild["id"]}/#{guild["icon"]}.png?size=#{size}"
  end

  def text_channels(channels) do
    Enum.filter(channels, &(&1["type"] == @guild_text))
  end

  def voice_channels(channels) do
    Enum.filter(channels, &(&1["type"] == @guild_voice))
  end
end
