import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sync, Sync.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sync_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :sync, whippy_api: "http://localhost:4000"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sync, SyncWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gmX2z57TwQ1J+BgX1D3qXiPlEBtAPTEyej1+0ho1nnTJ1h0JpIZpUB5eJKIBYWXa",
  server: false

# In test we don't send emails.
config :sync, Sync.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Capture all logs, but only show warnings and errors during test
config :logger, level: :debug
config :logger, :console, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

config :sync, Oban, testing: :inline

config :appsignal, :config, active: false

System.put_env("DASHBOARD_USERNAME", "username")
System.put_env("DASHBOARD_PASSWORD", "password")
