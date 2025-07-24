defmodule Sync.Workers.Aqore.CustomData.AqoreContacts do
  @moduledoc """
  Handles converting external contacts (client contacts) into sync custom object records.
  """

  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  import Ecto.Query

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Aqore.Parser

  def process(
        %Job{args: %{"type" => "process_contacts_as_custom_object_records", "integration_id" => integration_id}} = _job
      ) do
    Logger.info("Converting contacts to custom object records.",
      integration_id: integration_id,
      integration_client: :aqore
    )

    integration = Integrations.get_integration!(integration_id)

    metadata = [integration_id: integration_id, integration_client: integration.client]

    case Contacts.list_custom_objects_by_external_entity_type(integration, "aqore_contact") do
      [] ->
        Logger.error("No custom object found for contacts.", metadata)

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.CustomData.Converter.convert_external_contacts_to_custom_object_records(
          @parser_module,
          integration,
          custom_object,
          dynamic([c], like(c.external_contact_id, "cont-%"))
        )

      [_custom_object] ->
        Logger.error("contacts custom_object not synced to whippy.", metadata)

      _ ->
        Logger.error("Multiple custom objects found for contacts.", metadata)
    end

    :ok
  end
end
