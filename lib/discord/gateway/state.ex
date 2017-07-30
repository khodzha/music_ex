defmodule Discord.Gateway.State do
  use GenServer
  alias Discord.Gateway
  alias Discord.Gateway.VoiceState

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def process_message(%{"op" => 10, "s" => hb_seq, "d" => %{"heartbeat_interval" => hb_interval}}) do
    GenServer.call(__MODULE__, {:heartbeat_interval, hb_interval, hb_seq})
  end

  def process_message(%{"op" => 11, "s" => hb_seq}) do
    GenServer.call(__MODULE__, {:heartbeat, hb_seq})
  end

  def process_message(%{"t" => "READY", "s" => hb_seq, "d" => payload}) do
    GenServer.call(__MODULE__, {:ready, payload, hb_seq})
  end

  def process_message(%{"t" => "VOICE_STATE_UPDATE", "s" => hb_seq, "d" => payload}) do
    GenServer.call(__MODULE__, {:voice_state_update, payload, hb_seq})
  end

  def process_message(%{"t" => "VOICE_SERVER_UPDATE", "s" => hb_seq, "d" => payload}) do
    GenServer.call(__MODULE__, {:voice_server_update, payload, hb_seq})
  end

  def process_message(msg) do
    IO.puts "MSG WITHOUT HANDLER: #{inspect msg}"
  end

  # todo:
  # тут нужно сделать супервайзер, пушо нам не надо, чтоб при падении вебсокетной херни падал стэйт соединения
  def init(:ok) do
    {:ok, pid} = Gateway.start_link
    {:ok, voice_pid} = Discord.Gateway.VoiceState.start_link
    {:ok, %{gateway: pid, voice: voice_pid}}
  end

  def handle_call({:heartbeat_interval, hb_interval, _hb_seq}, _from, state) do
    state = Map.put(state, :heartbeat_interval, hb_interval)

    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, hb_interval)

    Discord.Gateway.send_frame(state.gateway, %{
      "op" => 2,
      "d" => %{
        "token" => Discord.Gateway.Url.bot_token(),
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

  def handle_call({:ready, payload, hb_seq}, _from, state) do
    state = Map.put(state, :session_id, payload["session_id"])
    state = Map.put(state, :hb_seq, hb_seq)

    Discord.Gateway.send_frame(state.gateway, %{
      "op" => 4,
      "d" => %{
        "guild_id": Application.get_env(:music_ex, :guild_id),
        "channel_id": Application.get_env(:music_ex, :channel_id),
        "self_mute": false,
        "self_deaf": true
      }
    })
    {:reply, :ok, state}
  end

  def handle_call({:voice_state_update, payload, hb_seq}, _from, state) do
    state = Map.put(state, :hb_seq, hb_seq)
    VoiceState.set_var(:session_id, payload["session_id"])
    VoiceState.set_var(:user_id, payload["user_id"])

    {:reply, :ok, state}
  end

  def handle_call({:voice_server_update, payload, hb_seq}, _from, state) do
    endpoint = payload
    |> Map.get("endpoint")
    |> String.split(":")
    |> List.first

    VoiceState.set_var(:endpoint, endpoint)
    VoiceState.set_var(:token, payload["token"])
    VoiceState.set_var(:server_id, payload["guild_id"])
    state = Map.put(state, :hb_seq, hb_seq)

    {:reply, :ok, state}
  end

  def handle_call({:heartbeat, _hb_seq}, _from, state) do
    state = Map.put(state, :heartbeat_received, DateTime.utc_now())

    {:reply, :ok, state}
  end

  def handle_cast(:send_heartbeat, state) do
    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, state.heartbeat_interval)

    IO.puts "################################# hb_seq: #{state.hb_seq}"
    Discord.Gateway.send_frame(state.gateway, %{
      "op" => 1,
      "d" => state.hb_seq
    })

    {:noreply, state}
  end
end
