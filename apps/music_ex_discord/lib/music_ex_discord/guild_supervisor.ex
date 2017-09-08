defmodule MusicExDiscord.GuildSupervisor do
  use Supervisor
  alias MusicExFrontend.Guild
  alias MusicExDiscord.Player

  def start_link(guild = %Guild{}) do
    name = via_tuple(guild)

    Supervisor.start_link(__MODULE__, guild, name: name)
  end

  def init(guild) do
    children = [
      {MusicExDiscord.Gateway.Supervisor, [guild]},
      {Player, [guild]},
    ]

    Supervisor.init(children, strategy: :rest_for_one)
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

  defp via_tuple(guild) do
    {:via, Registry, {:guilds_registry, "guild_supervisor_#{guild.guild_id}"}}
  end
end
