defmodule MusicExDiscord.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_guild_supervisor(guild) do
    spec = MusicExDiscord.GuildSupervisor.child_spec([guild])
    Supervisor.start_child(__MODULE__, spec)
  end

  def init(:ok) do
    children = [
      {Registry, [keys: :unique, name: :guilds_registry]},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
