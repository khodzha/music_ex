defmodule MusicExDiscord.GuildLookup do
  def find_state(%{guild_id: guild_id}) do
    lookup(guild_id, :state)
  end
  def find_state(guild_id) do
    lookup(guild_id, :state)
  end

  def find_voice_state(%{guild_id: guild_id}) do
    lookup(guild_id, :voice_state)
  end
  def find_voice_state(guild_id) do
    lookup(guild_id, :voice_state)
  end

  def find_player(%{guild_id: guild_id}) do
    lookup(guild_id, :player)
  end
  def find_player(guild_id) do
    lookup(guild_id, :player)
  end

  def find_gateway(%{guild_id: guild_id}) do
    find_gateway(guild_id)
  end
  def find_gateway(guild_id) do
    MusicExDiscord.Gateway.Supervisor.get_gateway(guild_id)
  end

  def find_voice_gateway(%{guild_id: guild_id}) do
    find_voice_gateway(guild_id)
  end
  def find_voice_gateway(guild_id) do
    MusicExDiscord.Gateway.Supervisor.get_voice_gateway(guild_id)
  end

  defp lookup(guild_id, key) do
    [{pid, _}] = Registry.lookup(:guilds_registry, "#{key}_#{guild_id}")
    pid
  end
end
