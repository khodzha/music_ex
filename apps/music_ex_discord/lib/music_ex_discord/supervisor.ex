defmodule MusicExDiscord.Supervisor do
  use Supervisor
  alias MusicExDiscord.Discord.Gateway.State

  def start_link do
    Supervisor.start_link(MusicExDiscord.Supervisor, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(State, []),
      worker(MusicExDiscord.Player, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
