defmodule MusicExDiscord.Discord.Gateway.State do
  use GenServer

  alias MusicExDiscord.Discord.Gateway
  alias MusicExDiscord.Discord.Voice.State, as: VoiceState
  alias MusicExDiscord.Player
  alias MusicExDiscord.GuildLookup

  def start_link(guild) do
    initial_state = %{
      guild_id: guild.guild_id,
      voice_channel_id: guild.voice_channel_id,
      text_channel_id: guild.text_channel_id,
      self_user_id: Application.get_env(:music_ex_discord, :self_user_id)
    }

    via_name = {:via, Registry, {:guilds_registry, "state_#{guild.guild_id}"}}
    GenServer.start_link(__MODULE__, initial_state, name: via_name)
  end

  def child_spec([guild]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [guild]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def set_status(pid, status) do
    GenServer.cast(pid, {:set_status, status})
  end

  def remove_status(pid) do
    GenServer.cast(pid, :remove_status)
  end

  def process_message(pid, %{"s" => hb_seq} = msg) do
    GenServer.call(pid, {:hb_seq, hb_seq})
    do_process_message(pid, msg)
  end

  def do_process_message(pid, %{"op" => 10, "d" => %{"heartbeat_interval" => hb_interval}}) do
    GenServer.call(pid, {:heartbeat_interval, hb_interval})
  end

  def do_process_message(pid, %{"op" => 11}) do
    GenServer.call(pid, :heartbeat)
  end

  def do_process_message(pid, %{"t" => "READY", "d" => payload}) do
    GenServer.call(pid, {:ready, payload})
  end

  def do_process_message(pid, %{"t" => "VOICE_STATE_UPDATE", "d" => payload}) do
    GenServer.call(pid, {:voice_state_update, payload})
  end

  def do_process_message(pid, %{"t" => "VOICE_SERVER_UPDATE", "d" => payload}) do
    GenServer.call(pid, {:voice_server_update, payload})
  end

  def do_process_message(pid, %{"t" => "MESSAGE_CREATE", "d" => payload}) do
    author = payload["author"]
    |> Map.take(["id", "username"])

    message = payload
    |> Map.take(["channel_id", "id", "content"])
    |> Map.put("author", author)

    GenServer.cast(pid, {:new_message, message})
  end

  def do_process_message(_pid, msg) do
    IO.puts "MSG WITHOUT HANDLER: #{inspect msg}"
  end

  def init(initial_state) do
    {:ok, initial_state}
  end

  def handle_call({:heartbeat_interval, hb_interval}, _from, state) do
    state = Map.put(state, :heartbeat_interval, hb_interval)

    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, hb_interval)

    gateway_pid = GuildLookup.find_gateway(state)
    Gateway.send_frame(gateway_pid, %{
      "op" => 2,
      "d" => %{
        "token" => MusicExDiscord.Discord.API.Url.bot_token(),
        "properties" => %{
          "$os" => "linux",
          "$browser" => "khodzha/music_ex",
          "$device" => "khodzha/music_ex",
          "$referrer" => "",
          "$referring_domain" => ""
        },
        "compress" => true,
        "large_threshold" => 250
      }
    })
    {:reply, :ok, state}
  end

  def handle_call({:ready, payload}, _from, state) do
    state = Map.put(state, :session_id, payload["session_id"])

    gateway_pid = GuildLookup.find_gateway(state)
    Gateway.send_frame(gateway_pid, %{
      "op" => 4,
      "d" => %{
        "guild_id": state.guild_id,
        "channel_id": state.voice_channel_id,
        "self_mute": false,
        "self_deaf": true
      }
    })
    {:reply, :ok, state}
  end

  def handle_call({:voice_state_update, payload}, _from, state) do
    self_user_id = state.self_user_id
    if payload["user_id"] == self_user_id do
      voice_pid = GuildLookup.find_voice_state(state)
      VoiceState.set_var(voice_pid, :session_id, payload["session_id"])
      VoiceState.set_var(voice_pid, :user_id, payload["user_id"])
    end

    {:reply, :ok, state}
  end

  def handle_call({:voice_server_update, payload}, _from, state) do
    endpoint = payload
    |> Map.get("endpoint")
    |> String.split(":")
    |> List.first

    voice_pid = GuildLookup.find_voice_state(state)
    VoiceState.set_var(voice_pid, :endpoint, endpoint)
    VoiceState.set_var(voice_pid, :token, payload["token"])
    VoiceState.set_var(voice_pid, :server_id, payload["guild_id"])


    {:reply, :ok, state}
  end

  def handle_call(:heartbeat, _from, state) do
    state = Map.put(state, :heartbeat_received, DateTime.utc_now())

    {:reply, :ok, state}
  end

  def handle_call({:hb_seq, hb_seq}, _from, state) do
    state = case hb_seq do
      nil -> state
      _ -> Map.put(state, :hb_seq, hb_seq)
    end
    {:reply, :ok, state}
  end

  def handle_cast({:new_message, %{"content" => "!playlist"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.inspect_playlist(player_pid)
    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!play " <> request}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.add_to_playlist(player_pid, request)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!pause"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.pause(player_pid)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!unpause"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.unpause(player_pid)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!skip"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.skip(player_pid)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!clear"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.clear(player_pid)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!info"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.help(player_pid)
    {:noreply, state}
  end
  def handle_cast({:new_message, %{"content" => "!help"}}, state) do
    player_pid = GuildLookup.find_player(state)
    Player.help(player_pid)
    {:noreply, state}
  end

  def handle_cast({:new_message, _message}, state) do
    {:noreply, state}
  end

  def handle_cast(:send_heartbeat, state) do
    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, state.heartbeat_interval)

    hb_seq = Map.get(state, :hb_seq)
    gateway_pid = GuildLookup.find_gateway(state)
    Gateway.send_frame(gateway_pid, %{
      "op" => 1,
      "d" => hb_seq
    })

    {:noreply, state}
  end

  def handle_cast({:set_status, status}, state) do
    gateway_pid = GuildLookup.find_gateway(state)
    Gateway.send_frame(gateway_pid, %{
      "op" => 3,
      "d" => %{
        "since": nil,
        "status": "online",
        "game": %{
          "name": status,
          "type": 0
        },
        "afk": false
      }
    })
    {:noreply, state}
  end

  def handle_cast(:remove_status, state) do
    gateway_pid = GuildLookup.find_gateway(state)
    Gateway.send_frame(gateway_pid, %{
      "op" => 3,
      "d" => %{
        "since": nil,
        "game": nil,
        "afk": false,
        "status": "online"
      }
    })
    {:noreply, state}
  end
end
