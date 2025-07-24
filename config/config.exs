# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :sync,
  ecto_repos: [Sync.Repo],
  generators: [timestamp_type: :utc_datetime]

config :sync,
  whippy_api: "https://api.whippy.co",
  whippy_dashboard: "https://app.whippy.co",
  avionte_api: "https://api.avionte.com",
  tempworks_api: "https://api.ontempworks.com",
  tempworks_webhook_api: "https://webhooks-api.ontempworks.com/api",
  loxo_api: "https://app.loxo.co/api",
  aqore_api: "https://zenoplehubapi.zenople.com",
  hubspot_api: "https://api.hubapi.com",
  hubspot_client_id: "43a2eefb-e6b0-4780-82d5-56a780424d5f",
  hubspot_client_secret: "a3edd9fd-e77d-4123-87cc-0a1089bfdb76",
  crelate_api: "https://app.crelate.com/api3",
  crelate_sandbox_api: "https://sandbox.crelate.com/api3"

# Configures the endpoint
config :sync, SyncWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SyncWeb.ErrorHTML, json: SyncWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Sync.PubSub,
  live_view: [signing_salt: "p0LombRS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :sync, Sync.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  sync: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  sync: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: :all

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :sync, :generators,
  migration: true,
  binary_id: true,
  timestamp_type: :utc_datetime,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

config :sync, Oban,
  engine: Oban.Pro.Engines.Smart,
  peer: Oban.Peers.Postgres,
  notifier: Oban.Notifiers.PG,
  queues: [
    tempworks: [limit: 4],
    tempworks_frequent: [limit: 10, global_limit: [allowed: 10, partition: [args: [:integration_id, :type]]]],
    avionte: [limit: 4, global_limit: [allowed: 4, partition: [args: [:integration_id, :type]]]],
    avionte_messages: [limit: 10, global_limit: [allowed: 10, partition: [args: [:integration_id, :type]]]],
    loxo: [limit: 5, global_limit: [allowed: 5, partition: [args: [:integration_id, :type]]]],
    aqore: [limit: 5, global_limit: [allowed: 5, partition: [args: [:integration_id, :type]]]],
    aqore_messages: [limit: 10, global_limit: [allowed: 10, partition: [args: [:integration_id, :type]]]],
    hubspot: [limit: 5, global_limit: [allowed: 5, partition: [args: [:integration_id, :type]]]],
    crelate: [limit: 5, global_limit: [allowed: 5, partition: [args: [:integration_id, :type]]]]
  ],
  repo: Sync.Repo,
  plugins: [
    {Oban.Pro.Plugins.DynamicLifeline, rescue_interval: :timer.minutes(1)},
    Oban.Pro.Plugins.DynamicCron,
    {Oban.Pro.Plugins.DynamicPruner,
     state_overrides: [
       cancelled: {:max_age, {15, :minutes}},
       completed: {:max_age, {3, :days}},
       discarded: {:max_age, {1, :week}}
     ]}
  ]

config :sync, Sync.Utils.Ecto.Vault, json_library: Jason

config :kaffy,
  # required keys
  # required
  otp_app: :sync,
  # required
  ecto_repo: Sync.Repo,
  # required
  router: SyncWeb.Router,
  # optional keys
  hide_dashboard: false,
  home_page: [schema: ["integrations", "integration"]],
  # since v0.10.0
  enable_context_dashboards: true,
  # since v0.10.0
  admin_title: "Whippy Sync",
  admin_footer: "Whippy ©️ 2025",
  admin_logo: "https://www.whippy.ai/logo.svg",
  extensions: [
    Sync.Admin.Kaffy.Extension
  ],
  resources: [
    integrations: [
      resources: [
        integration: [
          schema: Sync.Integrations.Integration,
          admin: Sync.Admin.Integrations.Integration
        ],
        user: [schema: Sync.Integrations.User, admin: Sync.Admin.Integrations.User]
      ]
    ],
    oban: [
      resources: [
        job: [schema: Oban.Job, admin: Sync.Admin.Oban.Job],
        cron: [schema: Oban.Pro.Cron]
      ]
    ],
    contacts: [
      resources: [
        contact: [schema: Sync.Contacts.Contact]
      ]
    ],
    activities: [
      resources: [
        activity: [schema: Sync.Activities.Activity]
      ]
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

import_config "appsignal.exs"
