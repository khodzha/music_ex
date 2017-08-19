defmodule MusicEx.Playlist do
  alias MusicEx.Playlist

  defstruct songs: [], now_playing: nil

  def new do
    %Playlist{}
  end

  def push(playlist, song) do
    %{playlist | songs: playlist.songs ++ [song]}
  end

  def play_next(playlist) do
    song = case playlist.now_playing do
      nil -> Enum.at(playlist.songs, 0)
      uuid ->
        case Enum.find_index(playlist.songs, &(&1.uuid == uuid)) do
          nil -> nil
          idx -> Enum.at(playlist.songs, idx + 1)
        end
    end
  end
end
