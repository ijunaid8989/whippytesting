defmodule Sync.Workers.Loxo.Writer do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Loxo worker to sync Loxo data from the Sync database
  to the Loxo API.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Clients.Loxo
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Workers
  alias Sync.Workers.Utils

  require Logger

  @messages_per_chunk 100

  @doc """
  Pushes contacts to Loxo for the given integration.

  ## Parameters
    - `integration`: The integration record.
    - `limit`: The number of contacts to sync in each batch.

  ## Logic
    - Fetches the API key and agency slug for the integration.
    - Lists contacts missing from the external integration.
    - Converts each contact to a Loxo person and creates the person in Loxo.
    - Updates the contact as synced in Loxo.
    - Recursively calls itself if the number of contacts equals the limit.

  ## Returns
    - `:ok` on success.
  """
  def push_contacts_to_loxo(integration, limit) do
    Logger.info("Pushing contacts to Loxo for Loxo integration #{integration.id}")

    {:ok, api_key} = Authentication.Loxo.get_api_key(integration)
    {:ok, agency_slug} = Authentication.Loxo.get_agency_slug(integration)

    contacts =
      Contacts.list_integration_contacts_missing_from_external_integration(
        integration,
        limit
      )

    Enum.each(contacts, fn contact ->
      contact
      |> Clients.Loxo.Parser.convert_contact_to_person()
      |> Clients.Loxo.create_person(api_key, agency_slug)
      |> then(fn
        {:ok, response} ->
          update_contact_synced_in_loxo(:loxo, integration, response, contact)

        {:error, error_message} ->
          Utils.log_contact_error(contact, "integration", error_message)
          :ok
      end)
    end)

    if length(contacts) == limit do
      push_contacts_to_loxo(integration, limit)
    end

    :ok
  end

  # Updates the contact as synced in Loxo.

  # ## Parameters
  #   - `type`: The type of integration (should be `:loxo`).
  #   - `integration`: The integration record.
  #   - `external_contact`: The external contact record.
  #   - `contact`: The contact record.

  # ## Returns
  #   - The updated contact record on success.
  #   - `:error` on failure.
  defp update_contact_synced_in_loxo(
         :loxo,
         integration,
         %{external_contact_id: external_id} = external_contact,
         %Contact{} = contact
       ) do
    Contacts.update_contact_synced_in_external_integration(
      integration,
      contact,
      external_id,
      external_contact,
      "person"
    )
  end

  defp update_contact_synced_in_loxo(_type, _integration, external_contact, contact) do
    Logger.error(
      "Mismatched arguments passed to update_contact_synced_in_loxo, external_contact: #{inspect(external_contact)}, contact: #{inspect(contact)}"
    )

    :error
  end

  @doc """
  Pushes daily person events to Loxo for the given integration and day.

  ## Parameters
    - `integration`: The integration record.
    - `day`: The date of the messages to sync (ISO 8601 format).
    - `limit`: The number of messages to sync in each batch.
    - `offset`: The number of messages to skip in each batch.

  ## Logic
    - Lists daily messages with timezone.
    - Syncs the messages to Loxo.
    - Recursively calls itself if the number of messages equals the limit.

  ## Returns
    - The result of the sync operation.
  """
  def bulk_push_daily_person_events_to_loxo(integration, day, limit, offset) do
    Logger.info(
      "pull activities; integration: #{inspect(integration)}, day: #{inspect(day)}, limit: #{inspect(limit)}, offset: #{inspect(offset)}"
    )

    messages =
      Activities.list_daily_whippy_messages_with_timezone(integration, day, limit, offset)

    synced_result = sync_daily_whippy_contact_messages_to_loxo(integration, day, messages)

    if Enum.count(messages) < limit do
      synced_result
    else
      bulk_push_daily_person_events_to_loxo(integration, day, limit, offset)
    end
  end

  # Syncs daily Whippy contact messages to Loxo.

  # ## Parameters
  #   - `integration`: The integration record.
  #   - `day`: The date of the messages to sync (ISO 8601 format).
  #   - `messages`: The list of messages to sync.

  # ## Logic
  #   - Groups messages by external contact ID.
  #   - Fetches the contact by external ID.
  #   - Syncs the messages to Loxo.

  # ## Returns
  #   - The result of the sync operation.
  defp sync_daily_whippy_contact_messages_to_loxo(integration, day, messages) do
    messages
    |> Enum.group_by(& &1.external_contact_id)
    |> Enum.each(fn {person_id, messages} ->
      case Contacts.get_contact_by_external_id(integration.id, person_id) do
        nil ->
          Logger.info("Loxo contact not found - person_id #{person_id}", request_id: integration.id)
          []

        contact ->
          Logger.info("[Loxo] Syncing #{Enum.count(messages)} messages for contact #{contact.name} on #{day} to Loxo",
            request_id: integration.id
          )

          sync_daily_messages_to_loxo(messages, contact, integration, person_id)
      end
    end)
  end

  defp sync_daily_messages_to_loxo([], _contact, _integration, _person_id), do: []

  defp sync_daily_messages_to_loxo(_messages, nil, _integration, _person_id), do: []

  defp sync_daily_messages_to_loxo(messages, contact, integration, person_id) do
    messages
    |> Enum.sort_by(
      fn message ->
        {:ok, datetime, _offset} = DateTime.from_iso8601(message.whippy_activity["created_at"])
        datetime
      end,
      {:desc, DateTime}
    )
    |> Enum.group_by(& &1.whippy_conversation_id)
    |> Enum.map(fn {conversation_id, messages} ->
      messages
      |> Enum.chunk_every(@messages_per_chunk)
      |> Enum.map(fn messages_chunk ->
        sync_args = %{
          messages_chunk: messages_chunk,
          conversation_id: conversation_id,
          integration: integration,
          contact: contact,
          person_id: person_id
        }

        sync_daily_message_chunk_to_loxo(sync_args)
      end)
    end)
  end

  # Syncs a chunk of daily messages to Loxo.

  # ## Parameters
  #   - `sync_args`: A map containing the sync arguments.

  # ## Logic
  #   - Extracts the first message ID and date.
  #   - Generates a conversation link.
  #   - Builds the message body.
  #   - Syncs the message to Loxo.
  #   - Saves the external activity to activity records.

  # ## Returns
  #   - The result of the sync operation.
  defp sync_daily_message_chunk_to_loxo(%{messages_chunk: []}), do: []

  defp sync_daily_message_chunk_to_loxo(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         person_id: person_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(
        first_message_id,
        conversation_id,
        integration.whippy_organization_id
      )

    current_day_timestamp = extract_first_message_date_to_day(messages_chunk)

    message_body =
      Enum.reduce(messages_chunk, "", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "<br/><br/>")
      end)

    message_body = "#{message_body} #{conversation_link}"

    message_body
    |> sync_message_to_loxo(integration, person_id, current_day_timestamp)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  # Saves the external activity to activity records.

  # ## Parameters
  #   - `response`: The response from the Loxo API.
  #   - `activities`: The list of activities to update.

  # ## Logic
  #   - Updates each activity with the external activity ID.

  # ## Returns
  #   - The updated activities on success.
  #   - `:error` on failure.
  defp save_external_activity_to_activity_records(response, activities) do
    case response do
      {:ok, %Loxo.Model.PersonEvent{id: external_activity_id} = external_activity} ->
        Enum.map(activities, fn activity ->
          Activities.update_activity_synced_in_external_integration(
            activity,
            "#{external_activity_id}",
            external_activity
          )
        end)

      error ->
        Logger.error("Error syncing Loxo person event: #{inspect(error)}")

        error
    end
  end

  # Syncs a message to Loxo.

  # ## Parameters
  #   - `message_body`: The body of the message to sync.
  #   - `integration`: The integration record.
  #   - `person_id`: The ID of the person in Loxo.
  #   - `current_day_timestamp`: The timestamp of the current day.

  # ## Logic
  #   - Fetches the API key and agency slug for the integration.
  #   - Builds the request body.
  #   - Creates the person event in Loxo.

  # ## Returns
  #   - The response from the Loxo API.
  defp sync_message_to_loxo(message_body, integration, person_id, current_day_timestamp) do
    {:ok, api_key} = Authentication.Loxo.get_api_key(integration)
    {:ok, agency_slug} = Authentication.Loxo.get_agency_slug(integration)

    activity_type_id = integration.settings["activity_type_id"]

    body = %{
      activity_type_id: activity_type_id,
      person_id: person_id,
      notes: message_body,
      created_at: current_day_timestamp
    }

    Clients.Loxo.create_person_event(api_key, agency_slug, body)
  end

  ###############
  ## Full Sync ##
  ###############

  @doc """
  Pushes all person events to Loxo for the given integration.

  ## Parameters
    - `integration`: The integration record.
    - `limit`: The number of contacts to sync in each batch.
    - `offset`: The number of contacts to skip in each batch.

  ## Returns
    - `:ok` on success.
  """
  def bulk_push_person_events_to_loxo(integration, limit, offset) do
    Logger.info("[Loxo] Pushing person events to Loxo for integration #{integration.id}")
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    synced_result =
      Enum.map(contacts, fn contact ->
        sync_all_time_whippy_contact_messages_to_loxo(
          integration,
          contact
        )
      end)

    if Enum.count(contacts) < limit do
      synced_result
    else
      bulk_push_person_events_to_loxo(integration, limit, offset + limit)
    end

    :ok
  end

  defp sync_all_time_whippy_contact_messages_to_loxo(
         integration,
         %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: person_id} = contact
       ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    Logger.info("[Loxo] Syncing #{Enum.count(messages)} messages for contact #{contact.name}")

    sync_all_time_messages_to_loxo(messages, contact, integration, person_id)
  end

  defp sync_all_time_messages_to_loxo([], _contact, _integration, _person_id), do: []

  defp sync_all_time_messages_to_loxo(messages, contact, integration, person_id) do
    messages
    |> Enum.sort_by(
      fn message ->
        {:ok, datetime, _offset} = DateTime.from_iso8601(message.whippy_activity["created_at"])
        datetime
      end,
      {:desc, DateTime}
    )
    |> Enum.group_by(& &1.whippy_conversation_id)
    |> Enum.flat_map(fn {conversation_id, messages} ->
      messages_by_date =
        Enum.group_by(messages, fn message ->
          {:ok, datetime, _offset} = DateTime.from_iso8601(message.whippy_activity["created_at"])
          DateTime.to_date(datetime)
        end)

      sync_args = %{
        conversation_id: conversation_id,
        integration: integration,
        contact: contact,
        person_id: person_id
      }

      chunk_messages_and_sync_to_loxo(messages_by_date, sync_args)
    end)
  end

  defp chunk_messages_and_sync_to_loxo(messages_by_date, sync_args) do
    Enum.flat_map(messages_by_date, fn {date, messages} ->
      # Grouping messages by day and respecting the 100 (defined in @messages_per_chunk) messages per activity limit
      messages
      |> Enum.chunk_every(@messages_per_chunk)
      |> Enum.map(fn messages_chunk ->
        sync_args = Map.put(sync_args, :messages_chunk, messages_chunk)

        Logger.info("[#{date}] Syncing backdated messages for contact #{sync_args.contact.name} - #{inspect(sync_args)}")

        sync_message_chunk_to_loxo(sync_args)
      end)
    end)
  end

  defp sync_message_chunk_to_loxo(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         person_id: person_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)
    first_message_timestamp = extract_first_message_date_to_day(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(
        first_message_id,
        conversation_id,
        integration.whippy_organization_id
      )

    message_body =
      Enum.reduce(messages_chunk, "#{conversation_link}<br/><br/>", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "<br/><br/>")
      end)

    message_body
    |> sync_message_to_loxo(integration, person_id, first_message_timestamp)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  #############
  ## Helpers ##
  #############

  defp extract_first_message_id([%Activity{whippy_activity: %{"id" => message_id}} | _]) do
    message_id
  end

  # Extract the date of the first message and convert it to 9am UTC
  # Example: 2024-07-22T12:21:33Z -> 2024-07-22T09:00:00Z
  defp extract_first_message_date_to_day([%Activity{whippy_activity: %{"created_at" => created_at}} | _]) do
    {:ok, datetime, _} = DateTime.from_iso8601(created_at)

    datetime
    |> DateTime.to_date()
    |> DateTime.new!(~T[09:00:00], "Etc/UTC")
    |> DateTime.to_string()
  end

  defp extract_first_message_date_to_day(_invalid_input), do: nil
end
