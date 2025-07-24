defmodule Sync.Workers.Aqore.Writer do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Aqore worker to sync Aqore data from the Sync database
  to the Aqore API.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Clients.Aqore.Model.Comment
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Workers
  alias Sync.Workers.Utils

  require Logger

  @messages_per_chunk 100

  ################
  ## Daily Sync ##
  ################

  def bulk_push_daily_comments_to_aqore(integration, day, limit, offset) do
    metadata = [integration_id: integration.id, integration_client: integration.client]
    Logger.info("Bulk pushing daily comments to Aqore for integration", metadata)

    messages =
      Activities.list_daily_whippy_messages_with_timezone(integration, day, limit, offset)

    synced_result = sync_daily_whippy_contact_messages_to_aqore(integration, day, messages)

    if Enum.count(messages) < limit do
      synced_result
    else
      bulk_push_daily_comments_to_aqore(integration, day, limit, offset + limit)
    end

    :ok
  end

  def bulk_push_frequently_comments_to_aqore(integration, day, limit, offset) do
    metadata = [integration_id: integration.id, integration_client: integration.client]

    messages =
      Activities.list_whippy_messages_with_the_gap_of_inactivity(integration, limit, offset)

    Logger.info("Frequently comments to Aqore messages", [count: Enum.count(messages)] ++ metadata)

    synced_result = sync_daily_whippy_contact_messages_to_aqore(integration, day, messages)

    if Enum.count(messages) < limit do
      synced_result
    else
      bulk_push_frequently_comments_to_aqore(integration, day, limit, offset + limit)
    end

    :ok
  end

  defp sync_daily_whippy_contact_messages_to_aqore(integration, day, messages) do
    messages
    |> Enum.group_by(& &1.external_contact_id)
    |> Enum.each(fn {person_id, messages} ->
      contact = Contacts.get_contact_by_external_id(integration.id, person_id)

      metadata = [
        integration_id: integration.id,
        integration_client: integration.client,
        date: day,
        person_id: person_id,
        count: Enum.count(messages)
      ]

      if contact do
        Logger.info("Daily Syncing messages for contact to Aqore", metadata)
      end

      sync_daily_messages_to_aqore(messages, contact, integration, person_id)
    end)
  end

  defp sync_daily_messages_to_aqore([], _contact, _integration, _person_id), do: []

  defp sync_daily_messages_to_aqore(_messages, nil, _integration, _person_id), do: []

  defp sync_daily_messages_to_aqore(messages, contact, integration, person_id) do
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
          person_id: String.replace(person_id, "cont-", ""),
          user_id: extract_first_user_id(messages_chunk)
        }

        sync_message_chunk_to_aqore(sync_args)
      end)
    end)
  end

  ###############
  ## Full Sync ##
  ###############

  def bulk_push_comments_to_aqore(integration, limit, offset) do
    metadata = [integration_id: integration.id, integration_client: integration.client]
    Logger.info("Pushing comments to Aqore for integration", metadata)
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    synced_result =
      Enum.map(contacts, fn contact ->
        sync_all_time_whippy_contact_messages_to_aqore(
          integration,
          contact
        )
      end)

    if Enum.count(contacts) < limit do
      synced_result
    else
      bulk_push_comments_to_aqore(integration, limit, offset + limit)
    end

    :ok
  end

  defp sync_all_time_whippy_contact_messages_to_aqore(
         integration,
         %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: person_id} = contact
       ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      name: contact.name,
      person_id: person_id,
      count: Enum.count(messages)
    ]

    Logger.info("Syncing messages for contact", metadata)

    sync_all_time_messages_to_aqore(messages, contact, integration, person_id)
  end

  defp sync_all_time_messages_to_aqore([], _contact, _integration, _person_id), do: []

  defp sync_all_time_messages_to_aqore(messages, contact, integration, person_id) do
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
        |> Enum.chunk_every(@messages_per_chunk)
        |> Enum.map(fn messages_chunk ->
          sync_args = %{
            messages_chunk: messages_chunk,
            conversation_id: conversation_id,
            integration: integration,
            contact: contact,
            person_id: String.replace(person_id, "cont-", ""),
            user_id: extract_first_user_id(messages_chunk)
          }

          metadata = [
            integration_id: integration.id,
            integration_client: integration.client,
            name: contact.name,
            person_id: person_id,
            args: sync_args
          ]

          Logger.info("Syncing backdated messages for contact", metadata)

          sync_message_chunk_to_aqore(sync_args)
        end)

      # Today's messages are synced as a single activity, while respecting the 10 messages per activity limit.
      today_activities =
        today_messages
        |> Enum.chunk_every(@messages_per_chunk)
        |> Enum.map(fn messages_chunk ->
          sync_args = %{
            messages_chunk: messages_chunk,
            conversation_id: conversation_id,
            integration: integration,
            contact: contact,
            person_id: String.replace(person_id, "cont-", ""),
            user_id: extract_first_user_id(messages_chunk)
          }

          metadata = [
            integration_id: integration.id,
            integration_client: integration.client,
            name: contact.name,
            person_id: person_id,
            args: sync_args
          ]

          Logger.info("Syncing today's messages for contact", metadata)

          sync_message_chunk_to_aqore(sync_args)
        end)

      backdated_activities ++ today_activities
    end)
  end

  defp sync_message_chunk_to_aqore(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         person_id: person_id,
         user_id: user_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(
        first_message_id,
        conversation_id,
        integration.whippy_organization_id
      )

    button =
      "<button onclick=\"window.open('#{conversation_link}', '_blank')\">Open messages in Whippy</button>"

    {message_body, activity_type} =
      Enum.reduce(messages_chunk, {"", nil}, fn message, {acc_body, _acc_type} ->
        msg_body = Workers.Utils.build_message_body(message, acc_body, contact, integration, "<br/><br/>")
        {msg_body, message.activity_type}
      end)

    message_body = "#{message_body} #{button}"

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      name: contact.name,
      person_id: person_id
    ]

    Logger.info("Syncing message for contact", metadata)

    message_body
    |> sync_comment_to_aqore(integration, person_id, user_id, activity_type)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  # """
  # Saves the external activity to activity records.
  # ## Parameters
  #   - `response`: The response from the Aqore API.
  #   - `activities`: The list of activities to update.
  # ## Logic
  #   - Updates each activity with the external activity ID.
  # ## Returns
  #   - The updated activities on success.
  #   - `:error` on failure.
  # """
  defp save_external_activity_to_activity_records(response, activities) do
    case response do
      {:ok, %Comment{commentId: external_activity_id} = external_activity} ->
        Enum.map(activities, fn activity ->
          Activities.update_activity_synced_in_external_integration(
            activity,
            "#{external_activity_id}",
            external_activity
          )
        end)

      error ->
        Logger.error("Error syncing Aqore comment", error: inspect(error))
        error
    end
  end

  @doc """
    Syncs a message to Aqore.
    ## Parameters
      - `message_body`: The body of the message to sync.
      - `integration`: The integration record.
      - `person_id`: The ID of the person in Aqore.
    ## Logic
      - Fetches the access token and base URL for the integration.
      - Builds the request body.
      - Creates the comment in Aqore.
    ## Returns
      - The response from the Aqore API.
  """
  def sync_comment_to_aqore(message_body, integration, person_id, user_id, activity_type) do
    metadata = [integration_id: integration.id, integration_client: integration.client, person_id: person_id]

    Logger.info("Pushing messages for integration", metadata)

    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    {subject, comment_type} =
      case activity_type do
        "email" -> {"Whippy Emails", "Email"}
        "call" -> {"Whippy Calls", "Call"}
        _ -> {"Whippy Messages", "Message"}
      end

    payload = %{
      "action" => "CommentTsk",
      "filters" => %{
        "source" => "Whippy",
        "subject" => subject,
        "comment" => message_body,
        "personId" => person_id,
        "userId" => user_id,
        "commentType" => comment_type
      }
    }

    Clients.Aqore.create_comment(details, payload)
  end

  def sync_individual_contact_to_aqore(integration, contact) do
    metadata = [integration_id: integration.id, integration_client: integration.client]

    Logger.info("Pushing individual contact for integration", metadata)

    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    opts = %{
      office_id: integration.settings["office_id"],
      office_name: integration.settings["office_name"]
    }

    contact
    |> Clients.Aqore.Parser.convert_contact_to_candidate(opts)
    |> then(fn
      {:error, error_message} ->
        Utils.log_contact_error(contact, "integration", error_message)
        {:error, error_message}

      candidate ->
        Clients.Aqore.create_candidate(candidate, details)
    end)
    |> then(fn
      {:ok, response} ->
        update_contact_synced_in_aqore(:aqore, integration, response, contact)

      {:error, error_message} ->
        Utils.log_contact_error(contact, "integration", error_message)
        :ok
    end)
  end

  def push_contacts_to_aqore(integration, limit) do
    metadata = [integration_id: integration.id, integration_client: integration.client, limit: limit]

    Logger.info("Pushing contacts for integration", metadata)

    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    contacts_to_sync =
      Contacts.list_integration_contacts_missing_from_external_integration(
        integration,
        limit
      )

    opts = %{
      office_id: integration.settings["office_id"],
      office_name: integration.settings["office_name"]
    }

    Enum.each(contacts_to_sync, fn contact ->
      contact
      |> Clients.Aqore.Parser.convert_contact_to_candidate(opts)
      |> then(fn
        {:error, error_message} ->
          Utils.log_contact_error(contact, "integration", error_message)
          {:error, error_message}

        candidate ->
          Clients.Aqore.create_candidate(candidate, details)
      end)
      |> then(fn
        {:ok, response} ->
          update_contact_synced_in_aqore(:aqore, integration, response, contact)

        {:error, error_message} ->
          Utils.log_contact_error(contact, "integration", error_message)
          :ok
      end)
    end)

    if Enum.count(contacts_to_sync) < limit do
      :ok
    else
      push_contacts_to_aqore(integration, limit + 100)
    end
  end

  #############
  ## Helpers ##
  #############

  defp update_contact_synced_in_aqore(
         :aqore,
         integration,
         %{external_contact_id: external_id} = external_contact,
         %Contact{} = contact
       ) do
    Contacts.update_contact_synced_in_external_integration(
      integration,
      contact,
      external_id,
      external_contact,
      "candidate"
    )
  end

  defp extract_first_message_id([%Activity{whippy_activity: %{"id" => message_id}} | _]) do
    message_id
  end

  defp extract_first_user_id([%Activity{external_user_id: external_user_id} | _]) do
    external_user_id
  end
end
