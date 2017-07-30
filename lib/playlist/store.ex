defmodule Playlist.Store do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create(name) do
    GenServer.call(__MODULE__, {:create, name})
  end

  def fetch(name) do
    GenServer.call(__MODULE__, {:fetch, name})
  end

  def init(:ok) do
    {:ok, {%{}, %{}}}
  end

  def handle_call({:create, name}, _from, {playlists, refs}) do
    if Map.has_key?(playlists, name) do
      {:reply, :ok, {playlists, refs}}
    else
      {:ok, pid} = Playlist.Supervisor.create_playlist
      ref = Process.monitor(pid)
      refs = Map.put(refs, ref, name)
      playlists = Map.put(playlists, name, pid)
      {:reply, :ok, {playlists, refs}}
    end
  end

  def handle_call({:fetch, name}, _from, {playlists, _refs} = state) do
    {:reply, Map.fetch(playlists, name), state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {playlists, refs}) do
    {name, refs} = Map.pop(refs, ref)
    playlists = Map.delete(playlists, name)
    {:noreply, {playlists, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
