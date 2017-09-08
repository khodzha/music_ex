defmodule MusicExDiscord.Discord.Gateway do
  use WebSockex
  alias MusicExDiscord.Discord.API.Url
  alias MusicExDiscord.Discord.Gateway.State
  alias MusicExDiscord.GuildLookup

  def start_link(guild_id) do
    {:ok, url} = Url.get_gateway_url()
    WebSockex.start_link(url, __MODULE__, %{guild_id: guild_id})
  end

  def child_spec([guild_id]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [guild_id]},
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
    IO.puts "Received -- #{inspect json}"
    process_frame(state, json)

    {:ok, state}
  end

  def handle_frame({:binary, compressed}, state) do
    json = unpack_binary(compressed)
    IO.puts "Received binary -- #{inspect json}"
    process_frame(state, json)

    {:ok, state}
  end

  def process_frame(state, json) do
    {:ok, msg} = Poison.decode(json)
    state_pid = GuildLookup.find_state(state.guild_id)
    State.process_message(state_pid, msg)
  end

  def unpack_binary(compressed) do
    z = :zlib.open()
    :zlib.inflateInit(z)
    [uncompressed | [] ] = :zlib.inflate(z, compressed)
    :zlib.inflateEnd(z)
    uncompressed
  end
end
