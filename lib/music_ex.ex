defmodule MusicEx do
  use Application

  def start(_type, _args) do
    [
      token: "BOT_TOKEN",
      guild_id: "GUILD_ID",
      text_channel_id: "CHANNEL_ID",
      voice_channel_id: "VOICE_CHANNEL_ID",
      self_user_id: "USER_ID"
    ] |> Enum.each(fn {key, os_var} ->
      IO.puts(inspect({key, os_var, Application.fetch_env(:music_ex, key), System.get_env(os_var)}))
      case Application.fetch_env(:music_ex, key) do
        :error -> Application.put_env(:music_ex, key, System.get_env(os_var))
        {:ok, nil} -> Application.put_env(:music_ex, key, System.get_env(os_var))
        {:ok, _} -> nil
      end
    end)

    MusicEx.Supervisor.start_link
  end
end
