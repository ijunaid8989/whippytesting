defmodule Sync.Workers.Avionte.Writer do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Avionte worker to sync Avionte data from the Sync database
  to the Avionte API.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Clients.Avionte
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Integrations.Integration
  alias Sync.Integrations.User
  alias Sync.Workers
  alias Sync.Workers.Avionte.Utils, as: AvionteUtils
  alias Sync.Workers.Utils

  require Logger

  @type error :: String.t()
  @type iso_8601_date :: String.t()

  @default_timezone "Etc/UTC"
  @daily_sms_summary_type_id -95
  @contact_activity_type_id -11
  ##################
  ##   Contacts   ##
  ##################

  def push_contacts_to_avionte(integration, limit) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    contacts =
      Contacts.list_integration_contacts_missing_from_external_integration(integration, limit)

    Enum.each(contacts, fn contact ->
      %User{external_user_id: representative_user_id} =
        Workers.Whippy.Reader.get_user_by_whippy_contact_id(integration, contact.whippy_contact_id)

      talent = Clients.Avionte.Parser.convert_contact_to_talent(contact)

      if talent.emailAddress != nil do
        talent
        |> Map.put(:representativeUser, representative_user_id)
        |> then(&Clients.Avionte.create_talent(api_key, access_token, tenant, &1))
        |> then(&update_contact_synced_in_avionte(:avionte, integration, &1, contact))
      else
        error_log = "Contact found without an email address"

        Logger.warning(
          "Skipping creating contact #{talent.firstName} to external #{integration.integration} integration #{integration.id}: #{error_log}"
        )

        Utils.log_contact_error(contact, "integration", error_log)
      end
    end)

    if length(contacts) == limit do
      push_contacts_to_avionte(integration, limit)
    end

    :ok
  end

  defp update_contact_synced_in_avionte(
         :avionte,
         integration,
         {:ok, %{external_contact_id: external_id} = external_contact},
         %Contact{} = contact
       ) do
    Contacts.update_contact_synced_in_external_integration(
      integration,
      contact,
      external_id,
      external_contact,
      "talent"
    )
  end

  defp update_contact_synced_in_avionte(integration_type, integration, error, %Contact{name: name, id: id} = contact) do
    error_log = inspect(error)

    Logger.error(
      "Error syncing contact #{name} with ID #{id} to external #{integration_type} integration #{integration.id}: #{error_log}"
    )

    Utils.log_contact_error(contact, "integration", error_log)

    error
  end

  ####################
  ##    Messages    ##
  ##  (daily sync)  ##
  ####################

  @doc """
  Creates a TalentActivity in Avionte of type "Daily SMS Summary" (typeId -95)
  with the messages of the day for each Contact record that is already already synced.

  ## Arguments:
    - `integration` - The Avionte integration record.
    - `day` - The date of the messages to sync i.e "2021-01-01".
    - `limit` - The number of contacts to sync in each batch.
    - `offset` - The number of contacts to skip in each batch.

  ## Logic:
    - For each contact that is already synced, fetch the messages for the given day.
    - Sort the messages by created_at date.
    - Group the messages by conversation_id.
    - For each conversation, chunk the messages into groups of 10.
    - For each chunk, create a message body with a conversation link and the messages.
    - Make a request to Avionte to create a TalentActivity with the message body.
    - Save the external_activity_id in the respective Activity records.
    - Repeat the process until all contacts are synced.

  ## Activity Body Format:
    - Structure:
      [Conversation Link]
      [Contact Name] [Message Timestamp] [Message Body]
      [User Name] [Message Timestamp] [Message Body]

    - Timestamp format:
      "Weekday, Day Month Year Hour:Minute AM/PM - Timezone Abbreviation" i.e "Tue, 11 Jun 24 3:15 PM - UTC"


  ## Returns:
    - A list of Activity records that were synced to Avionte and saved in the Sync database.
  """
  @spec bulk_push_daily_talent_activities_to_avionte(
          Integration.t(),
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Activity.t()]
  def bulk_push_daily_talent_activities_to_avionte(integration, day, limit, offset) do
    timezone = integration.settings["timezone"] || @default_timezone
    messages = Activities.list_daily_whippy_messages_with_timezone(integration, day, limit, offset, timezone)

    synced_result = sync_daily_whippy_contact_messages_to_avionte(integration, day, messages)

    if Enum.count(messages) < limit do
      synced_result
    else
      bulk_push_daily_talent_activities_to_avionte(integration, day, limit, offset)
    end
  end

  defp modify_integration(integration, contact) do
    if is_nil(Map.get(integration.settings, "branches_mapping", nil)) do
      integration
    else
      mapping =
        integration.settings
        |> Map.get("branches_mapping", [])
        |> Enum.find(fn mapping -> mapping["organization_id"] == contact.whippy_organization_id end)

      if is_nil(mapping) do
        integration
      else
        AvionteUtils.modify_integration(integration, mapping) || integration
      end
    end
  end

  defp sync_daily_whippy_contact_messages_to_avionte(integration, day, messages) do
    messages
    |> Enum.group_by(& &1.external_contact_id)
    |> Enum.each(fn {talent_id, messages} ->
      contact = Contacts.get_contact_by_external_id(integration.id, talent_id)

      integration = modify_integration(integration, contact)

      Logger.info("Syncing #{Enum.count(messages)} messages for contact #{contact.name} on #{day} to Avionte")

      sync_daily_messages_to_avionte(messages, contact, integration, talent_id)
    end)
  end

  defp sync_daily_messages_to_avionte([], _contact, _integration, _talent_id), do: []

  defp sync_daily_messages_to_avionte(_messages, nil, _integration, _talent_id), do: []

  defp sync_daily_messages_to_avionte(messages, contact, integration, talent_id) do
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
      |> Enum.chunk_every(10)
      |> Enum.map(fn messages_chunk ->
        sync_args = %{
          messages_chunk: messages_chunk,
          conversation_id: conversation_id,
          integration: integration,
          contact: contact,
          talent_id: talent_id
        }

        sync_daily_message_chunk_to_avionte(sync_args)
      end)
    end)
  end

  defp sync_daily_message_chunk_to_avionte(%{messages_chunk: []}), do: []

  defp sync_daily_message_chunk_to_avionte(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         talent_id: talent_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "<br/><br/>")
      end)

    message_body = "#{message_body} #{conversation_link}"

    user_id =
      Workers.Whippy.Reader.get_external_user_id_by_whippy_messages_or_conversation(
        integration,
        messages_chunk,
        conversation_id
      )

    additional_params = if user_id, do: %{userId: user_id}, else: %{}

    message_body
    |> sync_message_to_avionte(integration, talent_id, additional_params, conversation_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  ##################
  ##   Messages   ##
  ##  (full sync) ##
  ##################

  @doc """
  Creates a TalentActivity in Avionte of type "Daily SMS Summary" (typeId -95)
  with the messages of each Contact record that is already already synced.

  ## Arguments:
    - `integration` - The Avionte integration record.
    - `limit` - The number of contacts to sync in each batch.
    - `offset` - The number of contacts to skip in each batch.

  ## Logic:
    - For each contact that is already synced, fetch all the messages.
    - Sort the messages by created_at date.
    - Group the messages by conversation_id.
    - For each conversation, chunk the messages into groups of 10.
    - For each chunk, create a message body with a conversation link and the messages.
    - Make a request to Avionte to create a TalentActivity with the message body.
    - Save the external_activity_id in the respective Activity records.
    - Repeat the process until all contacts are synced.

   **Note:** The messages that are older than today are synced as one activity per conversation
             but not split into daily activities.

    ## Activity Body Format:
    - Structure:
      [Conversation Link]
      [Contact Name] [Message Timestamp] [Message Body]
      [User Name] [Message Timestamp] [Message Body]

    - Timestamp format:
      "Weekday, Day Month Year Hour:Minute AM/PM - Timezone Abbreviation" i.e "Tue, 11 Jun 24 3:15 PM - UTC"

  ## Returns:
    - A list of Activity records that were synced to Avionte and saved in the Sync database.
  """
  @spec bulk_push_talent_activities_to_avionte(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Activity.t()]
  def bulk_push_talent_activities_to_avionte(integration, limit, offset) do
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    synced_result =
      Enum.map(contacts, fn contact ->
        integration = modify_integration(integration, contact)

        sync_all_time_whippy_contact_messages_to_avionte(
          integration,
          contact
        )
      end)

    if Enum.count(contacts) < limit do
      synced_result
    else
      bulk_push_talent_activities_to_avionte(integration, limit, offset + limit)
    end
  end

  defp sync_all_time_whippy_contact_messages_to_avionte(
         integration,
         %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: talent_id} = contact
       ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    Logger.info("Syncing #{Enum.count(messages)} messages for contact #{contact.name} to Avionte")

    sync_all_time_messages_to_avionte(messages, contact, integration, talent_id)
  end

  defp sync_all_time_messages_to_avionte([], _contact, _integration, _talent_id), do: []

  defp sync_all_time_messages_to_avionte(messages, contact, integration, talent_id) do
    today = Date.utc_today()

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
      {older_messages, today_messages} =
        Enum.split_with(messages, fn message ->
          {:ok, datetime, _offset} = DateTime.from_iso8601(message.whippy_activity["created_at"])
          Date.before?(DateTime.to_date(datetime), today)
        end)

      # Backdated messages are synced as one activity per conversation but not split into daily activities,
      # The 10 messages per activity is still respected limit
      backdated_activities =
        older_messages
        |> Enum.chunk_every(10)
        |> Enum.map(fn messages_chunk ->
          sync_args = %{
            messages_chunk: messages_chunk,
            conversation_id: conversation_id,
            integration: integration,
            contact: contact,
            talent_id: talent_id
          }

          sync_message_chunk_to_avionte(sync_args)
        end)

      # Today's messages are synced as a single activity, while respecting the 10 messages per activity limit.
      today_activities =
        today_messages
        |> Enum.chunk_every(10)
        |> Enum.map(fn messages_chunk ->
          sync_args = %{
            messages_chunk: messages_chunk,
            conversation_id: conversation_id,
            integration: integration,
            contact: contact,
            talent_id: talent_id
          }

          sync_message_chunk_to_avionte(sync_args)
        end)

      backdated_activities ++ today_activities
    end)
  end

  defp sync_message_chunk_to_avionte(%{messages_chunk: []}), do: []

  defp sync_message_chunk_to_avionte(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         talent_id: talent_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)
    first_message_timestamp = extract_first_message_timestamp(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "#{conversation_link}<br/><br/>", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "<br/><br/>")
      end)

    user_id =
      Workers.Whippy.Reader.get_external_user_id_by_whippy_messages_or_conversation(
        integration,
        messages_chunk,
        conversation_id
      )

    additional_params =
      if user_id,
        do: %{userId: user_id, activityDate: first_message_timestamp},
        else: %{activityDate: first_message_timestamp}

    message_body
    |> sync_message_to_avionte(integration, talent_id, additional_params, conversation_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  # Common functions

  @type additional_fields :: [activityDate: String.t(), userId: integer()] | []
  @spec sync_message_to_avionte(String.t(), Integration.t(), non_neg_integer(), additional_fields, String.t()) ::
          {:ok, Avionte.Model.TalentActivity.t()} | {:error, error}
  defp sync_message_to_avionte(message_body, integration, talent_id, additional_fields, conversation_id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    if String.starts_with?(talent_id, "contact-") do
      type_id = integration.settings["contact_type_id"] || @contact_activity_type_id

      # Build the base body map
      base_body = %{notes: message_body, typeId: type_id}

      # Merge the additional fields into the base body
      body = Enum.into(additional_fields, base_body)

      updated_body =
        case Map.get(body, :activityDate) do
          nil ->
            activity_date =
              integration.id
              |> Activities.get_activity_date(conversation_id, talent_id)
              |> DateTime.to_iso8601()

            Map.put(body, :activityDate, activity_date)

          _ ->
            body
        end

      id = String.replace_prefix(talent_id, "contact-", "")

      payload = [contact_id: id, body: updated_body]

      Logger.info("Avionte contact activity payload #{inspect(payload)}")

      Clients.Avionte.create_contact_activity(api_key, token, tenant, payload)
    else
      type_id = integration.settings["type_id"] || @daily_sms_summary_type_id

      # Build the base body map
      base_body = %{notes: message_body, typeId: type_id}

      # Merge the additional fields into the base body
      body = Enum.into(additional_fields, base_body)

      payload = [talent_id: talent_id, body: body]

      Clients.Avionte.create_talent_activity(api_key, token, tenant, payload)
    end
  end

  defp save_external_activity_to_activity_records(response, activities) do
    case response do
      {:ok, %Avionte.Model.TalentActivity{id: external_activity_id} = external_activity} ->
        Enum.map(activities, fn activity ->
          Activities.update_activity_synced_in_external_integration(
            activity,
            "#{external_activity_id}",
            external_activity
          )
        end)

      {:ok, %Avionte.Model.ContactActivity{id: external_activity_id} = external_activity} ->
        Enum.map(activities, fn activity ->
          Activities.update_activity_synced_in_external_integration(
            activity,
            "#{external_activity_id}",
            external_activity
          )
        end)

      error ->
        Logger.error("Error syncing Avionte activity: #{inspect(error)}")

        error
    end
  end

  defp extract_first_message_id([%Activity{whippy_activity: %{"id" => message_id}} | _]) do
    message_id
  end

  defp extract_first_message_timestamp([%Activity{whippy_activity_inserted_at: timestamp} | _]) do
    DateTime.to_iso8601(timestamp)
  end
end
