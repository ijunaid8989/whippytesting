defmodule Sync.Workers.Aqore.Contacts do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers.Aqore

  require Logger

  @initial_limit_for_aqore_contact 400
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_contacts_from_aqore", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pulling contacts from Aqore for integration", metadata)

    Aqore.Reader.pull_aqore_contacts(integration, @initial_limit_for_aqore_contact, @initial_offset, :full_sync)
    :ok
  end

  def process(%Job{args: %{"type" => "daily_pull_contacts_from_aqore", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Daily pulling contacts from Aqore for integration", metadata)

    Aqore.Reader.pull_aqore_contacts(integration, @initial_limit_for_aqore_contact, @initial_offset, :daily_sync)
    :ok
  end
end
