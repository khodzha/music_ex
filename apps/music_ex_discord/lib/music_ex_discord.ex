defmodule MusicExDiscord do
  use Application

  def start(_type, _args) do
    load_env()

    result = MusicExDiscord.Supervisor.start_link()
    Task.start(&start_guilds/0)
    result
  end

  defp load_env do
    [
      token: "BOT_TOKEN",
      self_user_id: "USER_ID"
    ] |> Enum.each(&load_env_var/1)
  end

  defp load_env_var({key, os_var}) do
    case Application.fetch_env(:music_ex_discord, key) do
      :error -> Application.put_env(:music_ex_discord, key, System.get_env(os_var))
      {:ok, nil} -> Application.put_env(:music_ex_discord, key, System.get_env(os_var))
      {:ok, _} -> nil
    end
  end

  defp start_guilds() do
    :timer.sleep(1000)
    MusicExFrontend.Guild
    |> MusicExFrontend.Repo.all()
    |> Enum.each(fn guild ->
      MusicExDiscord.Supervisor.start_guild_supervisor(guild)
    end)
  end
end
