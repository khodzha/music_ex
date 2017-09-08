defmodule MusicExDiscord.Player do
  use GenServer

  alias MusicExDiscord.Discord.Gateway.State
  alias MusicExDiscord.Discord.Voice.State, as: VoiceState
  alias MusicExDiscord.Discord.API.Message
  alias MusicExDiscord.Discord.Voice.Encoder
  alias MusicExDiscord.Playlist
  alias MusicExDiscord.Song
  alias MusicExDiscord.YoutubeDL
  alias MusicExDiscord.GuildLookup

  @silence <<0xF8, 0xFF, 0xFE>>
  @default_ms 20

  def start_link(guild) do
    initial_state = %{
      guild_id: guild.guild_id,
      voice_channel_id: guild.voice_channel_id,
      text_channel_id: guild.text_channel_id
    }
    via_name = {:via, Registry, {:guilds_registry, "player_#{guild.guild_id}"}}
    GenServer.start_link(__MODULE__, initial_state, name: via_name)
  end

  def child_spec([guild]) do
    %{
      id: __MODULE__,
      start: { __MODULE__, :start_link, [guild]},
      restart: :permanent,
      shutdown: 500,
      type: :worker
     }
  end

  def add_to_playlist(pid, request) do
    GenServer.cast(pid, {:add_to_playlist, request})
  end

  def inspect_playlist(pid) do
    GenServer.cast(pid, :inspect_playlist)
  end

  def pause(pid) do
    GenServer.cast(pid, :pause)
  end

  def unpause(pid) do
    GenServer.cast(pid, :unpause)
  end

  def skip(pid) do
    GenServer.cast(pid, :skip)
  end

  def clear(pid) do
    GenServer.cast(pid, :clear)
  end

  def init(initial_state) do
    state = initial_state
    |> Map.put(:playlist, Playlist.new())
    |> Map.put(:sending_silence, false)
    {:ok, state}
  end

  def handle_cast({:add_to_playlist, request}, state) do
    pl = Playlist.push(state.playlist, request)
    send(self(), :added_to_playlist)
    {:noreply, %{state | playlist: pl}}
  end

  def handle_cast(:inspect_playlist, state) do
    s = Playlist.to_s(state.playlist)
    send_message("""
      Current playlist
      ==============================================================
      #{s}
      """
    )
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
    set_status(state, song.metadata["fulltitle"])
    play_packets(state.packets, GuildLookup.find_voice_state(state))
    {:noreply, state}
  end

  defp play_youtube(%Song{} = song, voice_pid) do
    YoutubeDL.binary_to_file(song.title)
    |> encode_packets(voice_pid)
    |> play_packets(voice_pid)

    YoutubeDL.metadata(song.title)
  end

  defp encode_packets(file_path, voice_pid) do
    file_path
    |> Encoder.encode()
    |> Stream.with_index()
    |> Enum.map(fn {frame, seq} ->
      VoiceState.encode(voice_pid, frame, seq)
    end)
  end

  defp play_packets(packets, voice_pid) do
    send_message("Started playing")
    VoiceState.speaking(voice_pid, true)
    elapsed = :os.system_time(:milli_seconds)
    send(self(), {:play_loop, packets, 0, elapsed})
  end

  def handle_info({:play_loop, [packet | rest], seq, elapsed}, state) do
    voice_pid = GuildLookup.find_voice_state(state)
    cond do
      Map.get(state, :paused) ->
        state = Map.put(state, :packets, rest)
        song = Playlist.current_song(state.playlist)
        set_status(state, ~s[Paused: #{song.metadata["fulltitle"]}])
        send_silence(voice_pid, seq + 1)
        {:noreply, %{ state | sending_silence: true }}

      Map.get(state, :skip) ->
        Process.send_after(
          self(),
          {:play_loop, [], seq + 1, elapsed + @default_ms},
          @default_ms
        )
        {:noreply, %{ state | skip: false }}

      Map.get(state, :clear) ->
        send_silence(voice_pid, seq + 1)
        {:noreply, %{ state | clear: false, playlist: Playlist.new() }}

      true ->
        if rem(seq, 1500) == 0 do
          Task.start(fn ->
            IO.puts(seq)
            VoiceState.speaking(voice_pid, true)
          end)
        end

        VoiceState.send_packet(voice_pid, packet)

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
    send_message("Finished playing")
    state_pid = GuildLookup.find_state(state)
    voice_pid = GuildLookup.find_voice_state(state)
    State.remove_status(state_pid)
    send(self(), :finished_playing)
    send_silence(voice_pid, seq + 1)
    pl = %Playlist{state.playlist | now_playing: nil}
    {:noreply, %{state | sending_silence: true, playlist: pl}}
  end

  def handle_info({:silence, _seq, 0}, state) do
    pid = GuildLookup.find_voice_state(state)
    VoiceState.speaking(pid, false)
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
    metadata = play_youtube(song, GuildLookup.find_voice_state(state))
    p = Playlist.set_song_metadata(state.playlist, song, metadata)
    set_status(state, song.metadata["fulltitle"])
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

  def handle_info({:send_message, text}, state) do
    Message.create(state.text_channel_id, text)
    {:noreply, state}
  end

  defp send_silence(voice_pid, seq) do
    VoiceState.encode(voice_pid, @silence, seq)
    Process.send_after(self(), {:silence, seq + 1, 5}, @default_ms)
  end

  defp maybe_play(%Playlist{now_playing: nil} = pl) do
    p = Playlist.play_next(pl)
    song = Playlist.current_song(p)
    unless is_nil(song), do: send(self(), :play)
    p
  end

  defp maybe_play(%Playlist{} = pl), do: pl

  defp send_message(text) do
    send(self(), {:send_message, text})
  end

  defp set_status(state, status) do
    state_pid = GuildLookup.find_state(state)
    State.set_status(state_pid, status)
  end
end
