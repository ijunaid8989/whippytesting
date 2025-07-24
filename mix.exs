defmodule Sync.MixProject do
  use Mix.Project

  def project do
    [
      app: :sync,
      version: "0.1.0",
      elixir: "~> 1.18.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Sync.Application, []},
      extra_applications: [:logger, :runtime_tools, :httpoison]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.19.3"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0.1"},
      {:floki, ">= 0.30.0", only: :test},
      {:mock, "~> 0.3.6"},
      {:ex_machina, "~> 2.4", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.4", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:swoosh, "~> 1.17"},
      {:finch, "~> 0.19"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.2"},
      {:oban, "~> 2.17.12"},
      {:oban_web, "~> 2.10.6", repo: "oban"},
      {:oban_pro, "~> 1.4.11", repo: "oban"},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.11", only: [:dev, :test], runtime: false},
      {:httpoison, "~> 2.0"},
      {:kaffy, "~> 0.10.0"},
      {:cloak_ecto, "~> 1.2.0"},
      {:timex, "~> 3.7.11"},
      {:ex_phone_number, "~> 0.4.4"},
      {:excoveralls, "~> 0.10", only: :test},
      {:tzdata, "> 1.1.1"},
      {:libphonenumber, "~> 0.1.1"},
      {:appsignal, "~> 2.8"},
      {:appsignal_phoenix, "~> 2.0"},
      {:faker, "~> 0.19.0-alpha.1", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind sync", "esbuild sync"],
      "assets.deploy": [
        "tailwind sync --minify",
        "esbuild sync --minify",
        "phx.digest"
      ]
    ]
  end
end
