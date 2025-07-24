defmodule Sync.Workers.Avionte.CustomData.Jobs do
  @moduledoc """
  Handles converting external jobs into sync custom object records.
  """

  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte.Utils

  require Logger

  @parser_module Sync.Clients.Avionte.Parser
  @initial_limit 500
  @initial_offset 0

  def process(%Job{args: %{"type" => "process_jobs_as_custom_object_records", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] Converting jobs to custom object records.")

    integration = Integrations.get_integration!(integration_id)

    integrations =
      case Map.get(integration.settings, "branches_mapping", nil) do
        nil ->
          [integration]

        mappings ->
          Enum.map(mappings, fn mapping -> Utils.modify_integration(integration, mapping) end)
      end

    Enum.each(integrations, fn integration ->
      case Contacts.list_custom_objects_by_external_entity_type(integration, "jobs") do
        [] ->
          Logger.error("[Avionte] [Integration #{integration_id}] No custom object found for jobs.")

        [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
          Workers.Avionte.Reader.pull_avionte_jobs(
            @parser_module,
            integration,
            custom_object,
            @initial_limit,
            @initial_offset
          )

        [_custom_object] ->
          Logger.error("[Avionte] [Integration #{integration_id}] jobs custom_object not synced to whippy.")

        _ ->
          Logger.error("[Avionte] [Integration #{integration_id}] Multiple custom objects found for jobs.")
      end
    end)

    :ok
  end
end
