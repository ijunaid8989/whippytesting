defmodule Sync.Workers.Avionte.CustomData.AvionteContacts do
  @moduledoc """
  Handles converting external contacts (talents) into sync custom object records.
  """

  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  import Ecto.Query

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte.Utils

  require Logger

  @parser_module Sync.Clients.Avionte.Parser

  def process(
        %Job{args: %{"type" => "process_contacts_as_custom_object_records", "integration_id" => integration_id}} = _job
      ) do
    Logger.info("[Avionte] [Integration #{integration_id}] Converting contacts to custom object records.")

    integration = Integrations.get_integration!(integration_id)

    integrations =
      case Map.get(integration.settings, "branches_mapping", nil) do
        nil ->
          [integration]

        mappings ->
          Enum.map(mappings, fn mapping -> Utils.modify_integration(integration, mapping) end)
      end

    Enum.each(integrations, fn integration ->
      case Contacts.list_custom_objects_by_external_entity_type(integration, "avionte_contact") do
        [] ->
          Logger.error("[Avionte] [Integration #{integration_id}] No custom object found for contact.")

        [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
          Workers.CustomData.Converter.convert_external_contacts_to_custom_object_records(
            @parser_module,
            integration,
            custom_object,
            build_condition(integration)
          )

        [_custom_object] ->
          Logger.error("[Avionte] [Integration #{integration_id}] contact custom_object not synced to whippy.")

        _ ->
          Logger.error("[Avionte] [Integration #{integration_id}] Multiple custom objects found for contact.")
      end
    end)

    :ok
  end

  defp build_condition(integration) do
    office_condition =
      if is_nil(integration.office_name) do
        dynamic(true)
      else
        dynamic([c], fragment("?->>'officeName' = ?", c.external_contact, ^integration.office_name))
      end

    client_condition = dynamic([c], like(c.external_contact_id, "contact-%"))

    dynamic([c], ^office_condition and ^client_condition)
  end
end
