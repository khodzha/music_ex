defmodule MusicExDiscord.Discord.Voice.Gateway do
  use WebSockex
  alias MusicExDiscord.Discord.Voice.State, as: VoiceState
  alias MusicExDiscord.GuildLookup

  def start_link(url, guild_id) do
    WebSockex.start_link(url, __MODULE__, %{guild_id: guild_id})
  end

  def child_spec([url, guild_id]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [url, guild_id]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def send_frame(pid, data) do
    {:ok, payload} = Poison.encode(data)
    WebSockex.send_frame(pid, {:text, payload})
  end

  def handle_frame({:text, json}, state) do
    IO.puts "Received voice -- #{inspect json} #{DateTime.utc_now()}"
    process_frame(state, json)

    {:ok, state}
  end

  def handle_frame({:binary, compressed}, state) do
    json = unpack_binary(compressed)
    IO.puts "Received voice binary -- #{inspect json}"
    process_frame(state, json)

    {:ok, state}
  end

  def process_frame(state, json) do
    {:ok, msg} = Poison.decode(json)
    voice_state_pid = GuildLookup.find_voice_state(state.guild_id)
    VoiceState.process_message(voice_state_pid, msg)
  end

  def unpack_binary(compressed) do
    z = :zlib.open()
    :zlib.inflateInit(z)
    [uncompressed | [] ] = :zlib.inflate(z, compressed)
    :zlib.inflateEnd(z)
    uncompressed
  end

  def handle_disconnect(connection_state, state) do
    IO.puts("voice gateway disconnect: #{inspect connection_state}")
    {:reconnect, state}
  end
end
