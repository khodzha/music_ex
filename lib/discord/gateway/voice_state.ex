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
    GenServer.call(__MODULE__, {:start_playing, payload})
    GenServer.cast(__MODULE__, :start)
  end

  def process_message(msg) do
    IO.puts "VOICESTATE NO HANDLER: #{inspect msg}"
  end

  def maybe_connect do
    GenServer.call(__MODULE__, :try_connect)
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

        wss_endpoint = "wss://#{endpoint}/?v=5&encoding=json"

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
      |> Map.take(["ip", "ssrc", "modes", "port", "heartbeat_interval"])
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
      |> Enum.into(%{})

    state = Map.merge(state, payload_slice)

    {:ok, udp_listener} = Socket.UDP.open
    state = Map.put(state, :udp_listener, udp_listener)

    # {:ok, {_, udp_port}} = Socket.local(udp_listener)

    ip_discovery_pckg = <<state.ssrc::size(32), 0::size(528)>>
    :ok = Socket.Datagram.send(udp_listener, ip_discovery_pckg, {state.udp_endpoint, state.port})

    { data, _ } = Socket.Datagram.recv!(udp_listener)

    << _::binary-size(4), ip::binary-size(64), our_port::little-integer-size(16) >> = data

    string_ip = ip
    |> :erlang.binary_to_list
    |> Enum.take_while(fn e -> e > 0 end)

    # {:ok, our_ip} = :inet.parse_address(string_ip)

    Discord.VoiceGateway.send_frame(state.voice_gateway, %{
      "op" => 1,
      "d" => %{
        "protocol" => "udp",
        "data" => %{
          "address" => string_ip,
          "port"    => our_port,
          "mode"    => "xsalsa20_poly1305"
        }
      }
    })

    {:reply, :ok, state}
  end

  def handle_call({:start_playing, payload}, _from, state) do
    secret_key = payload
    |> Map.get("secret_key")
    |> :erlang.list_to_binary

    state = Map.put(state, :secret_key, secret_key)

    Discord.VoiceGateway.send_frame(state.voice_gateway, %{
      "op" => 5,
      "d" => %{
        "speaking" => true,
        "delay" => 0
      }
    })

    {:reply, :ok, state}
  end

  def handle_cast(:start, state) do
    Task.async(fn ->
      IO.puts("started playing #{inspect DateTime.utc_now()}")

      Discord.Gateway.VoiceEncoder.encode("1.mp3")
      |> Stream.with_index
      |> Enum.map(fn {frame, seq} ->
        header = Discord.Gateway.VoiceEncoder.rtp_header(seq, state.ssrc)
        packet = Discord.Gateway.VoiceEncoder.encrypt_packet(frame, header, state.secret_key)
        {header <> packet, seq}
      end)
      |> Enum.each(fn {full_packet, seq} ->
        IO.puts(seq)
        if rem(seq, 1500) == 0 do
          Discord.VoiceGateway.send_frame(state.voice_gateway, %{
            "op" => 5,
            "d" => %{
              "speaking" => true,
              "delay" => 0
            }
          })
        end
        Socket.Datagram.send(state.udp_listener, full_packet, {state.udp_endpoint, state.port})
        :timer.sleep(20)
      end)

      IO.puts("finished playing #{inspect DateTime.utc_now()}")
    end)

    {:noreply, state}
  end
end
