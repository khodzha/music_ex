defmodule MusicEx.Player do
  use GenServer

  alias Discord.Gateway.State
  alias Discord.Voice.State, as: VoiceState
  alias Discord.Voice.Encoder
  alias MusicEx.Playlist
  alias MusicEx.Song
  alias MusicEx.YoutubeDL

  @silence <<0xF8, 0xFF, 0xFE>>
  @default_ms 20

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add_to_playlist(request) do
    GenServer.cast(__MODULE__, {:add_to_playlist, request})
  end

  def inspect_playlist do
    GenServer.cast(__MODULE__, :inspect_playlist)
  end

  def pause do
    GenServer.cast(__MODULE__, :pause)
  end

  def unpause do
    GenServer.cast(__MODULE__, :unpause)
  end

  def skip do
    GenServer.cast(__MODULE__, :skip)
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  def init(:ok) do
    {:ok, %{playlist: Playlist.new(), sending_silence: false}}
  end

  def handle_cast({:add_to_playlist, request}, state) do
    pl = Playlist.push(state.playlist, request)
    send(self(), :added_to_playlist)
    {:noreply, %{state | playlist: pl}}
  end

  def handle_cast(:inspect_playlist, state) do
    s = Playlist.to_s(state.playlist)
    Task.start(fn ->
      Discord.API.Message.create("""
      Current playlist
      ==============================================================
      #{s}
      """
      )
    end)
    {:noreply, state}
  end

  def handle_cast(:pause, state) do
    state = Map.put(state, :paused, true)
    {:noreply, state}
  end

  def handle_cast(:skip, state) do
    state = Map.put(state, :skip, true)
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    state = Map.put(state, :clear, true)
    {:noreply, state}
  end

  def handle_cast(:unpause, state) do
    state = Map.put(state, :paused, false)
    song = Playlist.current_song(state.playlist)
    State.set_status(song.metadata["fulltitle"])
    play_packets(state.packets)
    {:noreply, state}
  end

  defp play_youtube(%Song{} = song) do
    YoutubeDL.binary_to_file(song.title)
    |> encode_packets()
    |> play_packets()

    YoutubeDL.metadata(song.title)
  end

  defp encode_packets(file_path) do
    file_path
    |> Encoder.encode()
    |> Stream.with_index()
    |> Enum.map(fn {frame, seq} ->
      VoiceState.encode(frame, seq)
    end)
  end

  defp play_packets(packets) do
    Discord.API.Message.create("Started playing")
    VoiceState.speaking(true)
    elapsed = :os.system_time(:milli_seconds)
    send(self(), {:play_loop, packets, 0, elapsed})
  end

  def handle_info({:play_loop, [packet | rest], seq, elapsed}, state) do
    cond do
      Map.get(state, :paused) ->
        state = Map.put(state, :packets, rest)
        song = Playlist.current_song(state.playlist)
        State.set_status(~s[Paused: #{song.metadata["fulltitle"]}])
        send_silence(seq + 1)
        {:noreply, %{ state | sending_silence: true }}

      Map.get(state, :skip) ->
        Process.send_after(
          self(),
          {:play_loop, [], seq + 1, elapsed + @default_ms},
          @default_ms
        )
        {:noreply, %{ state | skip: false }}

      Map.get(state, :clear) ->
        send_silence(seq + 1)
        {:noreply, %{ state | clear: false, playlist: Playlist.new() }}

      true ->
        if rem(seq, 1500) == 0 do
          Task.start(fn ->
            IO.puts(seq)
            VoiceState.speaking(true)
          end)
        end

        VoiceState.send_packet(packet)

        now = :os.system_time(:milli_seconds)
        sleep_time = case elapsed - now + @default_ms do
          x when x < 0 -> 0
          x -> x
        end
        Process.send_after(
          self(),
          {:play_loop, rest, seq + 1, elapsed + @default_ms},
          sleep_time
        )

        state = Map.put(state, :packets, rest)

        {:noreply, state}
    end
  end

  def handle_info({:play_loop, [], seq, _elapsed}, state) do
    Discord.API.Message.create("Finished playing")
    State.remove_status()
    send(self(), :finished_playing)
    send_silence(seq + 1)
    pl = %Playlist{state.playlist | now_playing: nil}
    {:noreply, %{state | sending_silence: true, playlist: pl}}
  end

  def handle_info({:silence, _seq, 0}, state) do
    VoiceState.speaking(false)
    {:noreply, %{state | sending_silence: false}}
  end

  def handle_info({:silence, seq, frames_left}, state) do
    Process.send_after(
      self(),
      {:silence, seq + 1, frames_left - 1},
      @default_ms
    )
    {:noreply, state}
  end

  def handle_info(:play, state) do
    song = Playlist.current_song(state.playlist)
    metadata = play_youtube(song)
    p = Playlist.set_song_metadata(state.playlist, song, metadata)
    State.set_status(song.metadata["fulltitle"])
    {:noreply, %{ state | playlist: p}}
  end

  def handle_info(:added_to_playlist, state) do
    playlist = maybe_play(state.playlist)
    {:noreply, %{state | playlist: playlist}}
  end

  def handle_info(:finished_playing, %{sending_silence: true} = state) do
    Process.send_after(self(), :finished_playing, 5 * @default_ms)
    {:noreply, state}
  end

  def handle_info(:finished_playing, %{sending_silence: false} = state) do
    playlist = maybe_play(state.playlist)
    {:noreply, %{state | playlist: playlist}}
  end

  defp send_silence(seq) do
    VoiceState.encode(@silence, seq)
    Process.send_after(self(), {:silence, seq + 1, 5}, @default_ms)
  end

  defp maybe_play(%Playlist{now_playing: nil} = pl) do
    p = Playlist.play_next(pl)
    song = Playlist.current_song(p)
    unless is_nil(song), do: send(self(), :play)
    p
  end

  defp maybe_play(%Playlist{} = pl), do: pl
end
