defmodule Sync.Workers.Whippy.Writer do
  @moduledoc """
  Contains utility functions reused across workers,
  related to writing data to Whippy.
  """
  import Ecto.Query

  alias Sync.Authentication
  alias Sync.Clients.Aqore
  alias Sync.Clients.Avionte
  alias Sync.Clients.Crelate
  alias Sync.Clients.Hubspot
  alias Sync.Clients.Loxo
  alias Sync.Clients.Tempworks
  alias Sync.Clients.Whippy
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Integrations.Integration
  alias Sync.Workers.Utils

  require Logger

  @type iso_8601_date :: String.t()

  @task_timeout :timer.seconds(30)

  ##################
  ##   Contacts   ##
  ##################

  @spec daily_push_contacts_to_whippy(
          atom(),
          Integration.t(),
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Contact.t()]
  def daily_push_contacts_to_whippy(integration_type, %Integration{} = integration, day, limit, offset) do
    contacts =
      Contacts.daily_list_integration_contacts_missing_from_whippy(
        integration,
        day,
        limit,
        offset
      )

    if Enum.count(contacts) < limit do
      send_contacts_to_whippy(integration_type, integration, contacts)
    else
      send_contacts_to_whippy(integration_type, integration, contacts)

      daily_push_contacts_to_whippy(integration_type, integration, day, limit, offset)
    end
  end

  @spec push_contacts_to_whippy(
          atom(),
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Contact.t()]
  def push_contacts_to_whippy(integration_type, %Integration{} = integration, limit, offset, condition \\ dynamic(true)) do
    contacts =
      Contacts.list_integration_contacts_missing_from_whippy(
        integration,
        limit,
        offset,
        condition
      )

    if Enum.count(contacts) < limit do
      send_contacts_to_whippy(integration_type, integration, contacts)
    else
      send_contacts_to_whippy(integration_type, integration, contacts)

      push_contacts_to_whippy(integration_type, integration, limit, offset, condition)
    end
  end

  @spec update_contact_synced_in_whippy(
          {:ok, map()},
          Integration.t(),
          Contact.t()
        ) :: {:ok, Contact.t()} | {:error, Ecto.Changeset.t()}
  def update_contact_synced_in_whippy(
        {:ok, %{"data" => %{"id" => whippy_id} = whippy_contact}},
        integration,
        %Contact{} = contact
      ) do
    Contacts.update_contact_synced_in_whippy(
      integration,
      contact,
      whippy_id,
      whippy_contact
    )
  end

  def update_contact_synced_in_whippy(
        {:error, error},
        %Integration{id: integration_id},
        %Contact{name: name, id: id} = contact
      ) do
    error_log = inspect(error)

    error =
      "[Whippy] [Integration #{integration_id}] Error syncing contact #{name} with ID #{id} to Whippy: #{error_log}"

    Logger.error(error)

    Utils.log_contact_error(contact, "whippy", error_log)

    error
  end

  def monthly_push_birthdays_to_whippy(%Integration{} = integration, limit, offset, day) do
    contacts =
      Contacts.list_integration_contacts_birth_dates_missing_from_whippy(
        integration,
        limit,
        offset,
        day
      )

    send_contacts_to_whippy(:tempworks, integration, contacts)
  end

  ####################
  ## Custom Objects ##
  ####################

  @spec push_custom_objects(
          Integration.t(),
          non_neg_integer()
        ) :: [CustomObject.t()]
  def push_custom_objects(%Integration{} = integration, limit, condition \\ dynamic(true)) do
    custom_objects =
      Contacts.list_custom_objects_missing_from_whippy(
        integration,
        limit,
        condition
      )

    if Enum.count(custom_objects) < limit do
      send_custom_objects_to_whippy(integration, custom_objects)
    else
      send_custom_objects_to_whippy(integration, custom_objects)

      push_custom_objects(integration, limit, condition)
    end

    custom_properties =
      Contacts.list_custom_properties_missing_from_whippy(
        integration,
        limit
      )

    if Enum.count(custom_properties) < limit do
      send_custom_properties_to_whippy(integration, custom_properties)
    else
      send_custom_properties_to_whippy(integration, custom_properties)
      push_custom_objects(integration, limit, condition)
    end

    # Make sure to always send associations to whippy
    custom_properties = Contacts.list_custom_properties(integration.whippy_organization_id)

    if custom_properties != [] do
      send_associations_to_whippy(integration, custom_properties)
    end

    :ok
  end

  defp send_custom_objects_to_whippy(%Integration{} = integration, custom_objects) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    custom_objects
    |> Task.async_stream(
      fn custom_object ->
        custom_object
        |> Whippy.Parser.convert_custom_object_to_whippy_custom_object()
        |> send_custom_object_to_whippy(custom_object, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :custom_object)
  end

  defp send_custom_properties_to_whippy(%Integration{} = integration, custom_properties) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    custom_properties
    |> Task.async_stream(
      fn custom_property ->
        custom_property
        |> Whippy.Parser.convert_custom_property_to_whippy_custom_property()
        |> send_custom_property_to_whippy(custom_property, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :custom_property)
  end

  defp send_associations_to_whippy(%Integration{} = _integration, []), do: :ok

  defp send_associations_to_whippy(%Integration{} = integration, custom_properties) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    grouped_custom_properties =
      custom_properties |> Sync.Repo.reload() |> Enum.group_by(& &1.whippy_custom_object_id)

    Enum.each(grouped_custom_properties, fn
      # If there is no whippy custom object ID, we do nothing since we don't know
      # to which custom object we should add the associations
      {nil, _} ->
        :ok

      # When we know the custom object ID, we can proceed to make a request and add the associations
      {whippy_custom_object_id, custom_properties} ->
        custom_object = Contacts.get_custom_object_by_whippy_id(integration.id, whippy_custom_object_id)

        associations = handle_associations(custom_object, custom_properties, integration)
        whippy_associations = handle_whippy_associations(custom_object, custom_properties)

        custom_object_payload =
          %{}
          |> Map.merge(if associations != [], do: %{associations: associations}, else: %{})
          |> Map.merge(if whippy_associations != [], do: %{whippy_associations: whippy_associations}, else: %{})

        if map_size(custom_object_payload) > 0 do
          send_custom_object_to_whippy(custom_object_payload, custom_object, api_key, integration)
        end
    end)
  end

  defp handle_associations(custom_object, custom_properties, integration) do
    whippy_associations = custom_object.whippy_custom_object["associations"] || []
    external_associations = convert_references_to_associations(integration, custom_properties)

    group_keys = ["source_property_key", "target_property_key", "target_data_type_id"]
    combine_associations(external_associations, whippy_associations, group_keys)
  end

  defp handle_whippy_associations(custom_object, custom_properties) do
    whippy_associations = custom_object.whippy_custom_object["whippy_associations"] || []

    external_associations =
      Enum.flat_map(custom_properties, fn cp ->
        cp.external_custom_property["whippy_associations"] || []
      end)

    group_keys = ["source_property_key"]
    combine_associations(external_associations, whippy_associations, group_keys)
  end

  defp convert_references_to_associations(integration, custom_properties) do
    Enum.flat_map(custom_properties, fn custom_property ->
      references = custom_property.external_custom_property["references"] || []
      property_key = custom_property.external_custom_property["key"]

      references
      |> Enum.map(&enhance_reference_with_whippy_ids(&1, property_key, integration))
      |> Enum.reject(&(&1["target_data_type_id"] == nil))
    end)
  end

  defp enhance_reference_with_whippy_ids(reference, source_property_key, integration) do
    case Contacts.list_custom_objects_by_external_entity_type(
           integration,
           reference["external_entity_type"]
         ) do
      [referenced_custom_object] ->
        %{
          "type" => reference["type"],
          "target_data_type_id" => referenced_custom_object.whippy_custom_object_id,
          "target_property_key" => reference["external_entity_property_key"],
          "source_property_key" => source_property_key
        }

      [] ->
        Logger.error(
          "[Whippy] [Integration #{integration.id}] Referenced Custom Object with external_entity_type #{reference["external_entity_type"]} not found."
        )

        %{
          "type" => reference["type"],
          "target_data_type_id" => nil,
          "target_property_key" => nil,
          "source_property_key" => nil
        }
    end
  end

  #   Combines whippy_associations and external_associations, ensuring that:
  #  - Associations are grouped by source_property_key, target_property_key, and target_data_type_id.
  #  - "id" is retained from whippy_associations when available.
  #  - "delete" is kept if it exists in either association, or set to nil if it doesn't.
  #
  #  The `custom_merge` function ensures that when merging associations,
  #  if a property is present in both associations, the non-nil value is kept.
  #  For example, if a whippy assoc has "ID" set and the "ID" in the external assoc is nil,
  #  the "ID" in the whippy assoc will be kept.
  defp combine_associations(external_associations, whippy_associations, group_keys) do
    custom_merge = fn assoc, acc ->
      Map.merge(acc, assoc, fn _key, val1, val2 -> val1 || val2 end)
    end

    whippy_associations
    |> Kernel.++(external_associations)
    |> Enum.map(&Map.merge(%{"id" => nil, "delete" => nil}, &1))
    |> Enum.group_by(&Map.take(&1, group_keys))
    |> Enum.map(fn {_, associations} -> Enum.reduce(associations, %{}, custom_merge) end)
  end

  defp send_custom_object_to_whippy(custom_object_payload, custom_object, api_key, integration) do
    result =
      case custom_object.whippy_custom_object_id do
        nil ->
          Whippy.create_custom_object(api_key, custom_object_payload)

        whippy_id ->
          Whippy.update_custom_object(
            api_key,
            whippy_id,
            custom_object_payload
          )
      end

    update_custom_object_synced_in_whippy(result, integration, custom_object)
  end

  defp send_custom_property_to_whippy(custom_property_payload, custom_property, api_key, integration) do
    result =
      case custom_property.whippy_custom_property_id do
        nil ->
          Whippy.create_custom_property(api_key, custom_property.whippy_custom_object_id, custom_property_payload)

        whippy_id ->
          Whippy.update_custom_property(
            api_key,
            custom_property.whippy_custom_object_id,
            whippy_id,
            custom_property_payload
          )
      end

    update_custom_property_synced_in_whippy(result, integration, custom_property)
  end

  defp update_custom_object_synced_in_whippy({:ok, parsed_custom_object}, integration, custom_object) do
    Contacts.update_custom_object_synced_in_whippy(
      integration,
      custom_object,
      parsed_custom_object
    )
  end

  defp update_custom_object_synced_in_whippy({:error, error}, %Integration{id: integration_id}, custom_object) do
    error_log = inspect(error)

    error =
      "[Whippy] [Integration #{integration_id}] Error syncing CustomObject with ID #{custom_object.id} to Whippy: #{error_log}"

    Logger.error(error)

    Utils.log_custom_object_error(custom_object, "whippy", error_log)

    error
  end

  defp update_custom_property_synced_in_whippy({:ok, params}, _integration, custom_property) do
    params = Map.put(params, :should_sync_to_whippy, false)
    Contacts.update_custom_property(custom_property, params)
  end

  defp update_custom_property_synced_in_whippy({:error, error}, %Integration{id: integration_id}, custom_property) do
    error_log = inspect(error)

    error =
      "[Whippy] [Integration #{integration_id}] Error syncing CustomProperty with ID #{custom_property.id} to Whippy: #{error_log}"

    Logger.error(error)

    Utils.log_custom_property_error(custom_property, "whippy", error_log)

    error
  end

  ###########################
  ## Custom Object Records ##
  ###########################

  def push_custom_object_records(%Integration{} = integration, limit, condition \\ dynamic(true)) do
    custom_object_records =
      Contacts.list_custom_object_records_missing_from_whippy(
        integration,
        limit,
        condition
      )

    if Enum.count(custom_object_records) < limit do
      send_custom_object_records_to_whippy(integration, custom_object_records)
    else
      send_custom_object_records_to_whippy(integration, custom_object_records)

      push_custom_object_records(integration, limit, condition)
    end
  end

  def send_custom_object_records_to_whippy(%Integration{} = integration, custom_object_records) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    custom_object_records
    |> Task.async_stream(
      fn custom_object_record ->
        custom_object_record
        |> Whippy.Parser.convert_custom_object_record_to_whippy_custom_object_record()
        |> send_custom_object_record_to_whippy(custom_object_record, api_key, integration)
      end,
      max_concurrency: 4,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :custom_object_record)
  end

  defp send_custom_object_record_to_whippy(custom_object_record_payload, custom_object_record, api_key, integration) do
    result =
      case custom_object_record.whippy_custom_object_record_id do
        nil ->
          Whippy.create_custom_object_record(
            api_key,
            custom_object_record_payload.custom_object_id,
            custom_object_record_payload
          )

        whippy_id ->
          Whippy.update_custom_object_record(
            api_key,
            custom_object_record_payload.custom_object_id,
            whippy_id,
            custom_object_record_payload
          )
      end

    update_custom_object_record_synced_in_whippy(result, integration, custom_object_record)
  end

  defp update_custom_object_record_synced_in_whippy(
         {:ok, %{whippy_custom_object_record_id: whippy_id} = whippy_custom_object_record},
         integration,
         custom_object_record
       ) do
    Contacts.update_custom_object_record_synced_in_whippy(
      integration,
      custom_object_record,
      whippy_id,
      whippy_custom_object_record
    )
  end

  defp update_custom_object_record_synced_in_whippy(
         {:error, error},
         %Integration{id: integration_id},
         %CustomObjectRecord{id: id} = custom_object_record
       ) do
    error_log = inspect(error)

    error =
      "[Whippy] [Integration #{integration_id}] Error syncing CustomObjectRecord with ID #{id} to Whippy: #{error_log}"

    Logger.error(error)

    Utils.log_custom_object_record_error(custom_object_record, "whippy", error_log)

    error
  end

  #################################
  ##   Client-agnostic requests  ##
  ##    to update contacts       ##
  #################################

  @spec update_whippy_contact(
          Integration.t(),
          Contact.t(),
          map(),
          binary()
        ) :: {:ok, map()} | {:error, any()}
  def update_whippy_contact(integration, contact_record, contact_payload, whippy_contact_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    api_key
    |> Whippy.update_contact(whippy_contact_id, contact_payload)
    |> update_contact_synced_in_whippy(integration, contact_record)
  end

  #################################
  ##   Client-specific requests  ##
  ##     to push contacts        ##
  #################################

  def send_contacts_to_whippy(integration_type, integration, contacts)

  def send_contacts_to_whippy(:hubspot, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        :whippy_api_contact
        |> Hubspot.Parser.parse(contact)
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  def send_contacts_to_whippy(:aqore, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        contact
        |> Aqore.Parser.convert_contact_to_whippy_contact()
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  def send_contacts_to_whippy(:loxo, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        contact
        |> Loxo.Parser.convert_contact_to_whippy_contact()
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  def send_contacts_to_whippy(:tempworks, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        contact
        |> Tempworks.Parser.convert_employee_to_whippy_contact()
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  def send_contacts_to_whippy(:avionte, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        contact
        |> Avionte.Parser.convert_contact_to_whippy_contact()
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  def send_contacts_to_whippy(:crelate, %Integration{} = integration, contacts) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    contacts
    |> Task.async_stream(
      fn contact ->
        contact
        |> Crelate.Parser.convert_contact_to_whippy_contact()
        |> send_contact_to_whippy(contact, api_key, integration)
      end,
      max_concurrency: 2,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :contact)
  end

  defp send_contact_to_whippy(contact_payload, contact, api_key, integration) do
    api_key
    |> Whippy.create_contact(contact_payload)
    |> update_contact_synced_in_whippy(integration, contact)
  end

  defp log_task_results(tasks, integration_id, entity_type) do
    Enum.each(tasks, fn
      {:exit, {input, reason}} = error ->
        Logger.error(
          "[Whippy] [Integration #{integration_id}] Error syncing Sync #{entity_type} #{input.id} to Whippy: #{inspect(reason)}"
        )

        error

      ok ->
        ok
    end)
  end

  ##########################
  ## Developers and apps  ##
  ##########################

  def create_developer_application(integration, name, description) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)
    Whippy.create_application(api_key, name, description)
  end

  def create_developer_endpoint(integration, application_id, event_types, url) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)
    Whippy.create_developer_endpoint(api_key, application_id, event_types, url)
  end
end
