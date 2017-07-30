defmodule Discord.VoiceGateway do
  use WebSockex
  alias Discord.Gateway.VoiceState

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{})
  end

  def send_frame(pid, data) do
    {:ok, payload} = Poison.encode(data)
    WebSockex.send_frame(pid, {:text, payload})
  end

  def handle_frame({:text, json}, state) do
    IO.puts "Received voice -- #{inspect json}"
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
end
