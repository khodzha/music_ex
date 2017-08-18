defmodule Player do
  use GenServer

  alias Discord.Voice.State, as: VoiceState
  alias Discord.Voice.Encoder

  @silence <<0xF8, 0xFF, 0xFE>>

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
    start_playing(state.packets)
    {:noreply, state}
  end

  def download_from_youtube(request) do
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
    Poison.decode!(json_output)["_filename"]
  end

  defp play_youtube(request) do
    filename = download_from_youtube(request)

    play_file(filename)
  end

  defp play_file(file) do
    Encoder.encode(file)
    |> Stream.with_index()
    |> Enum.map(fn {frame, seq} ->
      VoiceState.encode(frame, seq)
    end)
    |> start_playing()
  end

  defp start_playing(packets) do
    VoiceState.speaking(true)
    elapsed = :os.system_time(:milli_seconds)
    send(self(), {:play_loop, packets, 0, elapsed})

    VoiceState.speaking(false)
  end

  def handle_info({:play_loop, [packet | rest], seq, elapsed}, state) do
    cond do
      Map.get(state, :stopped) ->
        state = Map.delete(state, :stopped)
        {:noreply, state}

      Map.get(state, :paused) ->
        state = Map.put(state, :packets, rest)
        {:noreply, state}

      true ->
        if rem(seq, 1500) == 0 do
          Task.start(fn ->
            IO.puts(seq)
            VoiceState.speaking(true)
          end)
        end

        VoiceState.send_packet(packet)

        sleep_time = case elapsed - :os.system_time(:milli_seconds) + 20 do
          x when x < 0 -> 0
          x -> x
        end
        Process.send_after(self(), {:play_loop, rest, seq+1, elapsed+20}, sleep_time)

        state = Map.put(state, :packets, rest)

        {:noreply, state}
    end
  end

  def handle_info({:play_loop, [], _seq, _elapsed}, state) do
    VoiceState.speaking(false)
    {:noreply, state}
  end
end
