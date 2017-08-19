defmodule Discord.Gateway.State do
  use GenServer
  alias Discord.Gateway
  alias Discord.Voice.State, as: VoiceState
  alias MusicEx.Player

  @guild_id         Application.get_env(:music_ex, :guild_id)
  @voice_channel_id Application.get_env(:music_ex, :voice_channel_id)
  @self_user_id     Application.get_env(:music_ex, :self_user_id)

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def set_status(status) do
    GenServer.cast(__MODULE__, {:set_status, status})
  end
  def remove_status do
    GenServer.cast(__MODULE__, :remove_status)
  end

  def process_message(%{"s" => hb_seq} = msg) do
    GenServer.call(__MODULE__, {:hb_seq, hb_seq})
    do_process_message(msg)
  end

  def do_process_message(%{"op" => 10, "d" => %{"heartbeat_interval" => hb_interval}}) do
    GenServer.call(__MODULE__, {:heartbeat_interval, hb_interval})
  end

  def do_process_message(%{"op" => 11}) do
    GenServer.call(__MODULE__, :heartbeat)
  end

  def do_process_message(%{"t" => "READY", "d" => payload}) do
    GenServer.call(__MODULE__, {:ready, payload})
  end

  def do_process_message(%{"t" => "VOICE_STATE_UPDATE", "d" => %{"user_id" => @self_user_id} = payload}) do
    GenServer.call(__MODULE__, {:voice_state_update, payload})
  end

  def do_process_message(%{"t" => "VOICE_SERVER_UPDATE", "d" => payload}) do
    GenServer.call(__MODULE__, {:voice_server_update, payload})
  end

  def do_process_message(%{"t" => "MESSAGE_CREATE", "d" => payload}) do
    author = payload["author"]
    |> Map.take(["id", "username"])

    message = payload
    |> Map.take(["channel_id", "id", "content"])
    |> Map.put("author", author)

    GenServer.cast(__MODULE__, {:new_message, message})
  end

  def do_process_message(msg) do
    IO.puts "MSG WITHOUT HANDLER: #{inspect msg}"
  end

  def init(:ok) do
    {:ok, pid} = Gateway.start_link
    {:ok, voice_pid} = VoiceState.start_link
    {:ok, %{gateway: pid, voice: voice_pid}}
  end

  def handle_call({:heartbeat_interval, hb_interval}, _from, state) do
    state = Map.put(state, :heartbeat_interval, hb_interval)

    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, hb_interval)

    Discord.Gateway.send_frame(state.gateway, %{
      "op" => 2,
      "d" => %{
        "token" => Discord.API.Url.bot_token(),
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

    Discord.Gateway.send_frame(state.gateway, %{
      "op" => 4,
      "d" => %{
        "guild_id": @guild_id,
        "channel_id": @voice_channel_id,
        "self_mute": false,
        "self_deaf": true
      }
    })
    {:reply, :ok, state}
  end

  def handle_call({:voice_state_update, payload}, _from, state) do
    VoiceState.set_var(:session_id, payload["session_id"])
    VoiceState.set_var(:user_id, payload["user_id"])

    {:reply, :ok, state}
  end

  def handle_call({:voice_server_update, payload}, _from, state) do
    endpoint = payload
    |> Map.get("endpoint")
    |> String.split(":")
    |> List.first

    VoiceState.set_var(:endpoint, endpoint)
    VoiceState.set_var(:token, payload["token"])
    VoiceState.set_var(:server_id, payload["guild_id"])


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

  def handle_cast({:new_message, %{"content" => "!play " <> file}}, state) do
    Player.play(file)

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!stop"}}, state) do
    Player.stop_playing()

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!pause"}}, state) do
    Player.pause()

    {:noreply, state}
  end

  def handle_cast({:new_message, %{"content" => "!unpause"}}, state) do
    Player.unpause()

    {:noreply, state}
  end

  def handle_cast({:new_message, _message}, state) do
    {:noreply, state}
  end

  def handle_cast(:send_heartbeat, state) do
    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, state.heartbeat_interval)

    hb_seq = Map.get(state, :hb_seq)
    Gateway.send_frame(state.gateway, %{
      "op" => 1,
      "d" => hb_seq
    })

    {:noreply, state}
  end

  def handle_cast({:set_status, status}, state) do
    Gateway.send_frame(state.gateway, %{
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
    Gateway.send_frame(state.gateway, %{
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
