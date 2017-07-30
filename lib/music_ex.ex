defmodule MusicEx do
  use Application

  def start(_type, _args) do
    MusicEx.Supervisor.start_link
  end
end
