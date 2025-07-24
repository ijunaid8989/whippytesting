defmodule Sync.Workers.Aqore.Users do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Aqore

  require Logger

  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_users_from_aqore", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pulling users for integration", metadata)

    Aqore.Reader.pull_aqore_users(integration, @initial_limit, @initial_offset, :full_sync)

    :ok
  end

  def process(%Job{args: %{"type" => "daily_pull_users_from_aqore", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Daily sync. Pulling users for integration", metadata)

    Aqore.Reader.pull_aqore_users(integration, @initial_limit, @initial_offset, :daily_sync)

    :ok
  end

  def process(%Job{args: %{"type" => "pull_users_from_whippy", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pulling users from Whippy", metadata)

    Workers.Whippy.Reader.pull_whippy_users(integration, @initial_limit, @initial_offset)

    :ok
  end
end
