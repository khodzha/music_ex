defmodule MusicEx.Playlist do
  alias MusicEx.Playlist
  alias MusicEx.Song

  defstruct songs: [], now_playing: nil, last_playing: nil

  def new do
    %Playlist{}
  end

  def push(playlist, %Song{} = song) do
    %{playlist | songs: playlist.songs ++ [song]}
  end

  def push(playlist, song) do
    push(playlist, Song.build(song))
  end

  def play_next(playlist) do
    song = case playlist.last_playing do
      nil -> Enum.at(playlist.songs, 0)
      uuid ->
        case Enum.find_index(playlist.songs, &(&1.uuid == uuid)) do
          nil -> nil
          idx -> Enum.at(playlist.songs, idx + 1)
        end
    end

    song_uuid = case song do
      nil -> nil
      %Song{uuid: uuid} -> uuid
    end

    {song, %{playlist | now_playing: song_uuid, last_playing: song_uuid}}
  end

  def to_s(p) do
    s = p.songs
    |> Stream.with_index()
    |> Enum.map(fn {s, idx} -> "  #{idx + 1}. #{s.uuid} #{s.title}" end)
    |> Enum.join("\n")

    "Now playing: #{p.now_playing}\nLast playing: #{p.last_playing}\n\n#{s}"
  end
end
