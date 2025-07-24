defmodule Sync.Workers.Aqore.Candidates do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Aqore

  require Logger

  @initial_limit_for_aqore_contact 400
  @initial_limit 800
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_candidates_from_aqore", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pulling candidates from Aqore for integration", metadata)

    Aqore.Reader.pull_aqore_candidates(integration, @initial_limit_for_aqore_contact, @initial_offset, :full_sync)
    :ok
  end

  def process(%Job{args: %{"type" => "daily_pull_candidates_from_aqore", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Daily sync. Pulling candidates from Aqore.", metadata)

    Aqore.Reader.pull_aqore_candidates(integration, @initial_limit_for_aqore_contact, @initial_offset, :daily_sync)
    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pulling contacts from Whippy for Aqore integration", metadata)

    Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)
    :ok
  end

  def process(%Job{args: %{"type" => "lookup_candidates_in_aqore", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Daily sync. Looking up whippy contacts in Aqore.", metadata)

    integration_id
    |> Integrations.get_integration!()
    |> Aqore.Reader.lookup_candidates_in_aqore(@initial_limit)
  end

  def process(%Job{args: %{"type" => "push_contacts_to_aqore", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pushing contacts to Aqore for integration", metadata)

    # TODO: implement push contacts to Aqore - this cannot be done at the moment as there is no supported API for this
    Workers.Aqore.Writer.push_contacts_to_aqore(integration, @initial_limit)
    :ok
  end

  def process(%Job{args: %{"type" => "push_candidates_to_whippy", "integration_id" => integration_id}}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    Logger.info("Pushing candidates to Whippy for integration", metadata)

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :aqore,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end
end
