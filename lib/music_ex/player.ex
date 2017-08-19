defmodule MusicEx.Player do
  use GenServer

  alias Discord.Gateway.State
  alias Discord.Voice.State, as: VoiceState
  alias Discord.Voice.Encoder

  @silence <<0xF8, 0xFF, 0xFE>>
  @default_ms 20

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def play(file) do
    GenServer.cast(__MODULE__, {:play, file})
  end

  def pause do
    GenServer.cast(__MODULE__, :pause)
  end

  def unpause do
    GenServer.cast(__MODULE__, :unpause)
  end

  def stop_playing do
    GenServer.cast(__MODULE__, :stop)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:play, request}, state) do
    play_youtube(request)
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    state = Map.put(state, :stopped, true)
    {:noreply, state}
  end

  def handle_cast(:pause, state) do
    state = Map.put(state, :paused, true)
    {:noreply, state}
  end

  def handle_cast(:unpause, state) do
    state = Map.put(state, :paused, false)
    play_packets(state.packets)
    {:noreply, state}
  end

  defp play_youtube(request) do
    request
    |> download_from_youtube()
    |> set_status()
    |> extract_json_filename()
    |> encode_packets()
    |> play_packets()
  end

  defp download_from_youtube(request) do
    query = URI.encode_www_form(request)
    {json_output, 0} = System.cmd(
      "youtube-dl", [
        "--print-json",
        "--id",
        "-q",
        "-w",
        "-f",
        "bestaudio",
        "--playlist-items",
        "1",
        "https://www.youtube.com/results?search_query=#{query}&page=1"
      ]
    )
    Poison.decode!(json_output)
  end

  defp set_status(json) do
    State.set_status(json["fulltitle"])
    json
  end

  defp extract_json_filename(json) do
    json["_filename"]
  end

  defp encode_packets(file) do
    file
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
      Map.get(state, :stopped) ->
        state = Map.delete(state, :stopped)
        send_silence(seq + 1)
        {:noreply, state}

      Map.get(state, :paused) ->
        state = Map.put(state, :packets, rest)
        send_silence(seq + 1)
        {:noreply, state}

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
    send_silence(seq + 1)
    {:noreply, state}
  end

  def handle_info({:silence, _seq, 0}, state) do
    VoiceState.speaking(false)
    {:noreply, state}
  end
  def handle_info({:silence, seq, frames_left}, state) do
    Process.send_after(
      self(),
      {:silence, seq + 1, frames_left - 1},
      @default_ms
    )
    {:noreply, state}
  end

  defp send_silence(seq) do
    VoiceState.encode(@silence, seq)
    Process.send_after(self(), {:silence, seq + 1, 5}, @default_ms)
  end
end