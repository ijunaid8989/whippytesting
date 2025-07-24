defmodule Sync.Workers.Aqore.CustomData.CustomObjects do
  @moduledoc """
  Handles fetching custom objects from Whippy and Aqore and storing them in the Sync app,
  as well as pushing custom objects and custom object records to Whippy.
  """

  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Clients.Aqore.Model.AqoreContact
  alias Sync.Clients.Aqore.Model.Candidate
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Aqore.Parser
  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_custom_objects_from_whippy", "integration_id" => integration_id}} = _job) do
    metadata = [integration_id: integration_id, integration_client: :aqore]
    Logger.info("Pulling custom_objects from Whippy.", metadata)

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_custom_objects(
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_custom_objects_from_aqore", "integration_id" => integration_id}} = _job) do
    metadata = [integration_id: integration_id, integration_client: :aqore]
    Logger.info("pulling custom_objects from Aqore.", metadata)

    integration = Integrations.get_integration!(integration_id)

    Workers.CustomData.CustomObjects.pull_custom_objects(
      @parser_module,
      integration,
      external_entity_type_to_model_mapper()
    )

    Logger.info("Custom objects records completed", metadata)

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_objects_to_whippy", "integration_id" => integration_id}} = _job) do
    metadata = [integration_id: integration_id, integration_client: :aqore]
    Logger.info("Pushing custom_objects with properties to Whippy.", metadata)

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_custom_objects(
      integration,
      @initial_limit
    )

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_object_records_to_whippy", "integration_id" => integration_id}} = _job) do
    metadata = [integration_id: integration_id, integration_client: :aqore]
    Logger.info("Pushing custom_object_records to Whippy.", metadata)

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_custom_object_records(
      integration,
      @initial_limit
    )

    :ok
  end

  defp external_entity_type_to_model_mapper do
    %{
      "candidate" => %Candidate{},
      "job_candidate" => fn integration ->
        Workers.Aqore.Reader.get_job_candidates_custom_details(integration, @initial_limit, @initial_offset, :full_sync)
      end,
      "job" => fn integration ->
        Workers.Aqore.Reader.get_job_custom_details(integration, @initial_limit, @initial_offset, :full_sync)
      end,
      "assignment" => fn integration ->
        Workers.Aqore.Reader.get_assignment_custom_details(integration, @initial_limit, @initial_offset, :full_sync)
      end,
      "organization_data" => fn integration ->
        Workers.Aqore.Reader.get_organization_custom_details(integration, @initial_limit, @initial_offset, :full_sync)
      end,
      "aqore_contact" => %AqoreContact{}
    }
  end
end
