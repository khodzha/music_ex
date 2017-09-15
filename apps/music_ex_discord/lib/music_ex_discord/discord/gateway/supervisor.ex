defmodule MusicExDiscord.Gateway.Supervisor do
  use Supervisor
  alias MusicExDiscord.Discord.Gateway.State
  alias MusicExDiscord.Discord.Voice.State, as: VoiceState

  def start_link(guild) do
    via_name = {:via, Registry, {:guilds_registry, "gateway_supervisor_#{guild.guild_id}"}}
    Supervisor.start_link(__MODULE__, guild, name: via_name)
  end

  def child_spec([guild]) do
    %{
      id: __MODULE__,
      start: { __MODULE__, :start_link, [guild]},
      restart: :permanent,
      shutdown: 500,
      type: :supervisor
     }
  end

  def start_voice_gateway(url, guild_id) do
    [{pid, _}] = Registry.lookup(:guilds_registry, "gateway_supervisor_#{guild_id}")
    spec = MusicExDiscord.Discord.Voice.Gateway.child_spec([url, guild_id])
    Supervisor.start_child(pid, spec)
  end

  def get_gateway(guild_id) do
    find_child(guild_id, MusicExDiscord.Discord.Gateway)
  end

  def get_voice_gateway(guild_id) do
    find_child(guild_id, MusicExDiscord.Discord.Voice.Gateway)
  end

  def init(guild) do
    children = [
      {State, [guild]},
      {VoiceState, [guild]},
      {MusicExDiscord.Discord.Gateway, [guild.guild_id]},
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp find_child(guild_id, module) do
    [{pid, _}] = Registry.lookup(:guilds_registry, "gateway_supervisor_#{guild_id}")

    gateway_tuple = pid
    |> Supervisor.which_children()
    |> Enum.find(fn {id, _, _, _} ->
      id == module
    end)

    {_, pid, _, _} = gateway_tuple
    pid
  end
end
