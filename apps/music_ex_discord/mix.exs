defmodule MusicExDiscord.Mixfile do
  use Mix.Project

  def project do
    [
      app: :music_ex_discord,
      version: "0.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:logger, :porcelain],
      mod: {MusicExDiscord, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.12"},
      {:poison, "~> 3.1"},
      {:websockex, "~> 0.3.1"},
      {:socket, "~> 0.3.12"},
      {:dogma, "~> 0.1", only: :dev},
      {:kcl, "~> 1.0"},
      {:uuid, "~> 1.1"},
      {:porcelain, "~> 2.0"},
      {:temp, "~> 0.4"}
    ]
  end
end
