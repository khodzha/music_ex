defmodule Discord.Gateway.VoiceState do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def set_var(varname, value) when varname in [:token, :session_id, :endpoint, :user_id, :server_id] do
    GenServer.call(__MODULE__, {:set_var, varname, value})
    maybe_connect()
  end

  def process_message(%{"op" => 2, "d" => payload}) do
    GenServer.call(__MODULE__, {:ready, payload})
  end

  def process_message(%{"op" => 4, "d" => payload}) do
    GenServer.call(__MODULE__, {:session_description, payload})
  end

  # received heartbeat ACK, do nothing
  def process_message(%{"op" => 6}) do
  end

  def process_message(%{"op" => 8, "d" => %{"heartbeat_interval" => hb_interval}}) do
    GenServer.call(__MODULE__, {:heartbeat_interval, hb_interval})
  end

  def process_message(msg) do
    IO.puts "VOICESTATE NO HANDLER: #{inspect msg}"
  end

  def maybe_connect do
    GenServer.call(__MODULE__, :try_connect)
  end

  def play(file) do
    GenServer.cast(__MODULE__, {:play ,file})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:set_var, varname, value}, _from, state) when varname in [:token, :session_id, :endpoint, :user_id, :server_id] do
    state = case varname do
      :endpoint ->
        [endpoint | _ ] = String.split(value, ":")

        {:ok, udp_endpoint} = endpoint
        |> String.to_charlist
        |> :inet.getaddr(:inet)

        wss_endpoint = "wss://#{endpoint}/?v=3&encoding=json"

        state
        |> Map.put(:endpoint, wss_endpoint)
        |> Map.put(:udp_endpoint, udp_endpoint)

      _ ->
        Map.put(state, varname, value)
    end
    {:reply, :ok, state}
  end

  def handle_call(:try_connect, _from, state) do
    all_keys_present = Enum.all?([:token, :session_id, :endpoint, :user_id, :server_id], fn k ->
      Map.has_key?(state, k)
    end)

    if all_keys_present do
      {:ok, pid} = Discord.VoiceGateway.start_link(state.endpoint)
      state = Map.put(state, :voice_gateway, pid)
      Discord.VoiceGateway.send_frame(state.voice_gateway, %{
        "op" => 0,
        "d" => %{
          "server_id" => state.server_id,
          "user_id" => state.user_id,
          "session_id" => state.session_id,
          "token" => state.token
        }
      })
      {:reply, :ok, state}
    else
      {:reply, :not_enough_info, state}
    end
  end

  def handle_call({:ready, payload}, _from, state) do
    payload_slice =
      payload
      |> Map.take(["ip", "ssrc", "modes", "port"])
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
      |> Enum.into(%{})

    state = Map.merge(state, payload_slice)

    {:ok, udp_listener} = Socket.UDP.open
    state = Map.put(state, :udp_listener, udp_listener)

    {our_ip, our_port} = ip_and_port_discovery(state)

    Discord.VoiceGateway.send_frame(state.voice_gateway, %{
      "op" => 1,
      "d" => %{
        "protocol" => "udp",
        "data" => %{
          "address" => our_ip,
          "port"    => our_port,
          "mode"    => "xsalsa20_poly1305"
        }
      }
    })

    {:reply, :ok, state}
  end

  def handle_call({:session_description, payload}, _from, state) do
    secret_key = payload
    |> Map.get("secret_key")
    |> :erlang.list_to_binary

    state = Map.put(state, :secret_key, secret_key)

    {:reply, :ok, state}
  end

  def handle_call({:heartbeat_interval, hb_interval}, _from, state) do
    state = Map.put(state, :heartbeat_interval, hb_interval)

    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, hb_interval)
    {:reply, :ok, state}
  end

  def handle_cast({:play, file}, state) do
    Task.async(fn ->
      play(state, file)
    end)

    {:noreply, state}
  end

  # TODO: something is wrong with hearbeats here
  def handle_cast(:send_heartbeat, state) do
    Process.send_after(self(), {:"$gen_cast", :send_heartbeat}, state.heartbeat_interval)

    hb_seq = Map.get(state, :hb_seq)
    Discord.Gateway.send_frame(state.voice_gateway, %{
      "op" => 3,
      "d" => hb_seq
    })

    {:noreply, state}
  end

  defp speaking(gateway, speaking_flag) do
    Discord.VoiceGateway.send_frame(gateway, %{
      "op" => 5,
      "d" => %{
        "speaking" => speaking_flag,
        "delay" => 0
      }
    })
  end

  defp play(state, file) do
    IO.puts("started playing #{inspect DateTime.utc_now()}")

    speaking(state.voice_gateway, true)

    Discord.Gateway.VoiceEncoder.encode(file)
    |> Stream.with_index
    |> Enum.map(fn {frame, seq} ->
      header = Discord.Gateway.VoiceEncoder.rtp_header(seq, state.ssrc)
      packet = Discord.Gateway.VoiceEncoder.encrypt_packet(frame, header, state.secret_key)
      {header <> packet, seq}
    end)
    |> Enum.reduce(:os.system_time(:milli_seconds), fn {full_packet, seq}, elapsed ->

      if rem(seq, 1500) == 0 do
        Task.async(fn ->
          IO.puts(seq)
          speaking(state.voice_gateway, true)
        end)
      end
      Socket.Datagram.send!(state.udp_listener, full_packet, {state.udp_endpoint, state.port})

      sleep_time = case elapsed - :os.system_time(:milli_seconds) + 20 do
        x when x < 0 -> 0
        x -> x
      end
      :timer.sleep(sleep_time)
      elapsed + 20
    end)

    speaking(state.voice_gateway, false)

    IO.puts("finished playing #{inspect DateTime.utc_now()}")
  end

  defp ip_and_port_discovery(state) do
    ip_discovery_pckg = <<state.ssrc::size(32), 0::size(528)>>
    :ok = Socket.Datagram.send(state.udp_listener, ip_discovery_pckg, {state.udp_endpoint, state.port})

    { data, _ } = Socket.Datagram.recv!(state.udp_listener)

    << _::binary-size(4), ip::binary-size(64), our_port::little-integer-size(16) >> = data

    string_ip = ip
    |> :erlang.binary_to_list
    |> Enum.take_while(fn e -> e > 0 end)

    {string_ip, our_port}
  end
end
