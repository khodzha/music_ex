defmodule Playlist do
  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def push(pid, song) do
    Agent.update(pid, fn list -> list ++ [song] end)
  end

  def pop(pid) do
    Agent.get_and_update(pid, fn [hd|tl] ->
      {hd, tl}
    end)
  end
end
