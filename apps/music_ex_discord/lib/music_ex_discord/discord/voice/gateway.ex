defmodule MusicExDiscord.Discord.Voice.Gateway do
  use WebSockex
  alias MusicExDiscord.Discord.Voice.State, as: VoiceState

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{})
  end

  def send_frame(pid, data) do
    {:ok, payload} = Poison.encode(data)
    WebSockex.send_frame(pid, {:text, payload})
  end

  def handle_frame({:text, json}, state) do
    IO.puts "Received voice -- #{inspect json} #{DateTime.utc_now()}"
    process_frame(json)

    {:ok, state}
  end

  def handle_frame({:binary, compressed}, state) do
    json = unpack_binary(compressed)
    IO.puts "Received voice binary -- #{inspect json}"
    process_frame(json)

    {:ok, state}
  end

  def process_frame(json) do
    {:ok, msg} = Poison.decode(json)
    VoiceState.process_message(msg)
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
