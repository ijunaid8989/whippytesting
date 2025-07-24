defmodule Sync.Workers.Avionte.CustomData.Placements do
  @moduledoc """
  Handles converting external placements into sync custom object records.
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

  def process(
        %Job{args: %{"type" => "process_placements_as_custom_object_records", "integration_id" => integration_id}} = _job
      ) do
    Logger.info("[Avionte] [Integration #{integration_id}] Converting placements to custom object records.")

    integration = Integrations.get_integration!(integration_id)

    integrations =
      case Map.get(integration.settings, "branches_mapping", nil) do
        nil ->
          [integration]

        mappings ->
          Enum.map(mappings, fn mapping -> Utils.modify_integration(integration, mapping) end)
      end

    Enum.each(integrations, fn integration ->
      case Contacts.list_custom_objects_by_external_entity_type(integration, "placements") do
        [] ->
          Logger.error("[Avionte] [Integration #{integration_id}] No custom object found for placements.")

        [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
          Workers.Avionte.Reader.pull_avionte_placements(
            @parser_module,
            integration,
            custom_object,
            @initial_limit,
            @initial_offset
          )

        [_custom_object] ->
          Logger.error("[Avionte] [Integration #{integration_id}] placements custom_object not synced to whippy.")

        _ ->
          Logger.error("[Avionte] [Integration #{integration_id}] Multiple custom objects found for placements.")
      end
    end)

    :ok
  end
end
