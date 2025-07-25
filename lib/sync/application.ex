defmodule Sync.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ets.new(:code_verifiers, [:named_table, :set, :public])
    :ets.new(:integrations, [:named_table, :set, :public])

    children = [
      SyncWeb.Telemetry,
      Sync.Repo,
      {DNSCluster, query: Application.get_env(:sync, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sync.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Sync.Finch},
      # Start a worker by calling: Sync.Worker.start_link(arg)
      # {Sync.Worker, arg},
      # Start to serve requests, typically the last entry
      SyncWeb.Endpoint,
      {Oban, Application.fetch_env!(:sync, Oban)},
      Sync.Utils.Ecto.Vault
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sync.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SyncWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
