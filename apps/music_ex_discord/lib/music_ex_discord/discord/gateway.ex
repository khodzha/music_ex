defmodule MusicExDiscord.Discord.Gateway do
  use WebSockex
  alias MusicExDiscord.Discord.API.Url
  alias MusicExDiscord.Discord.Gateway.State

  def start_link do
    {:ok, url} = Url.get_gateway_url()
    WebSockex.start_link(url, __MODULE__, %{})
  end

  def send_frame(pid, data) do
    {:ok, payload} = Poison.encode(data)
    WebSockex.send_frame(pid, {:text, payload})
  end

  def handle_frame({:text, json}, state) do
    IO.puts "Received -- #{inspect json}"
    process_frame(json)

    {:ok, state}
  end

  def handle_frame({:binary, compressed}, state) do
    json = unpack_binary(compressed)
    IO.puts "Received binary -- #{inspect json}"
    process_frame(json)

    {:ok, state}
  end

  def process_frame(json) do
    {:ok, msg} = Poison.decode(json)
    State.process_message(msg)
  end

  def unpack_binary(compressed) do
    z = :zlib.open()
    :zlib.inflateInit(z)
    [uncompressed | [] ] = :zlib.inflate(z, compressed)
    :zlib.inflateEnd(z)
    uncompressed
  end
end
