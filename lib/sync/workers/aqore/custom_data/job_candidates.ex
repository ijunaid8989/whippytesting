defmodule Sync.Workers.Aqore.CustomData.JobCandidates do
  @moduledoc """
  Handles converting external job contacts (job candidates) into sync custom object records.
  """

  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Aqore.Parser
  @initial_limit 800
  @initial_offset 0

  def process(
        %Job{args: %{"type" => "process_job_candidates_as_custom_object_records", "integration_id" => integration_id}} =
          _job
      ) do
    Logger.info("Converting job candidates to custom object records.",
      integration_id: integration_id,
      integration_client: :aqore
    )

    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    case Contacts.list_custom_objects_by_external_entity_type(integration, "job_candidate") do
      [] ->
        Logger.error("No custom object found for job candidates.", metadata)

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.Aqore.Reader.pull_job_candidates(
          @parser_module,
          integration,
          custom_object,
          @initial_limit,
          @initial_offset,
          :full_sync
        )

      [_custom_object] ->
        Logger.error("job_candidate custom_object not synced to whippy.", metadata)

      _ ->
        Logger.error("Multiple custom objects found for job candidate.", metadata)
    end

    :ok
  end

  def process(
        %Job{
          args: %{"type" => "process_daily_job_candidates_as_custom_object_records", "integration_id" => integration_id}
        } = _job
      ) do
    Logger.info("Daily sync. Converting daily job candidates to custom object records.",
      integration_id: integration_id,
      integration_client: :aqore
    )

    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]

    case Contacts.list_custom_objects_by_external_entity_type(integration, "job_candidate") do
      [] ->
        Logger.error("Daily sync. No custom object found for job candidates.", metadata)

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object | _] when not is_nil(whippy_id) ->
        Workers.Aqore.Reader.pull_job_candidates(
          @parser_module,
          integration,
          custom_object,
          @initial_limit,
          @initial_offset,
          :daily_sync
        )

      [_custom_object] ->
        Logger.error("Daily sync. job_candidate custom_object not synced to whippy.", metadata)

      _ ->
        Logger.error("Daily sync. Multiple custom objects found for job candidate.", metadata)
    end

    :ok
  end
end
