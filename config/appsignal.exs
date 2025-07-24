import Config

config :appsignal, :config,
  otp_app: :sync,
  name: "sync",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY") || "default_key",
  env: System.get_env("ENV_TYPE") || Mix.env(),
  enable_error_backend: true,
  enable_host_metrics: true,
  instrument_oban: true,
  report_oban_errors: "all"
