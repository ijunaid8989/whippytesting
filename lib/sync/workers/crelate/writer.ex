defmodule Sync.Workers.Crelate.Writer do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Crelate worker to sync Crelate data from the Sync database
  to the Crelate API.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers
  alias Sync.Workers.Utils

  require Logger

  @default_timezone "Etc/UTC"

  @type iso_8601_date :: String.t()
  @type error :: String.t()

  ##################
  ##   Contacts   ##
  ##################

  @spec push_contacts_to_crelate(
          Integration.t(),
          iso_8601_date(),
          non_neg_integer()
        ) :: [{:ok, Contact.t()} | {:error, Ecto.Changeset.t()} | error()]
  def push_contacts_to_crelate(%Integration{authentication: %{"external_api_key" => api_key}} = integration, day, limit) do
    contacts =
      Contacts.daily_list_integration_contacts_missing_from_external_integration(
        integration,
        day,
        limit
      )

    if Enum.count(contacts) < limit do
      sync_bulk_contacts_to_crelate(integration, api_key, contacts)
    else
      sync_bulk_contacts_to_crelate(integration, api_key, contacts)

      push_contacts_to_crelate(integration, day, limit)
    end
  end

  @spec push_contacts_to_crelate(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [{:ok, Contact.t()} | {:error, Ecto.Changeset.t()} | error()]
  def push_contacts_to_crelate(%Integration{authentication: %{"external_api_key" => api_key}} = integration, limit) do
    contacts =
      Contacts.list_integration_contacts_missing_from_external_integration(integration, limit)

    if Enum.count(contacts) < limit do
      sync_bulk_contacts_to_crelate(integration, api_key, contacts)
    else
      sync_bulk_contacts_to_crelate(integration, api_key, contacts)

      push_contacts_to_crelate(integration, limit)
    end
  end

  def sync_individual_contact_to_crelate(integration, api_key, contact) do
    contact_to_create = Clients.Crelate.Parser.convert_contact_to_crelate_contact(contact)

    contact_to_create
    |> Clients.Crelate.create_contact(api_key, integration.settings["use_production_url"])
    |> update_contact_synced_in_crelate(integration, contact)
  end

  def sync_bulk_contacts_to_crelate(integration, api_key, contacts) do
    contacts_to_create = Clients.Crelate.Parser.convert_contact_to_crelate_bulk_contacts(contacts)

    contacts_to_create
    |> Clients.Crelate.create_bulk_contacts(api_key, integration.settings["use_production_url"])
    |> update_bulk_contacts_synced_in_crelate(integration, contacts)
  end

  defp update_contact_synced_in_crelate({:ok, %{Id: entity_id}}, integration, contact) do
    Contacts.update_contact_synced_in_external_integration(
      integration,
      contact,
      entity_id,
      %{Id: entity_id},
      nil,
      %{}
    )
  end

  defp update_contact_synced_in_crelate({:error, error}, integration, %Contact{name: name} = contact) do
    error_log = inspect(error)

    Logger.error("[Crelate] Error syncing contact #{name} to external integration #{integration.id}: #{error_log}")

    Utils.log_contact_error(contact, "integration", error_log)

    error
  end

  defp update_bulk_contacts_synced_in_crelate({:ok, ids}, integration, contacts) do
    ids
    |> Enum.zip(contacts)
    |> Enum.each(fn {entity_id, contact} ->
      Contacts.update_contact_synced_in_external_integration(
        integration,
        contact,
        entity_id,
        %{Id: entity_id},
        nil,
        %{}
      )
    end)
  end

  defp update_bulk_contacts_synced_in_crelate(
         {:error, error},
         %Integration{authentication: %{"external_api_key" => api_key}} = integration,
         contacts
       ) do
    error_log = inspect(error)

    Logger.error("[Crelate] Error syncing bulk contacts to external integration #{integration.id}: #{error_log}")

    Enum.each(contacts, fn contact ->
      sync_individual_contact_to_crelate(integration, api_key, contact)
    end)
  end

  ##################
  ##   Messages   ##
  ##################

  ##################
  ##   Messages   ##
  ## (daily sync) ##
  ##################

  def bulk_push_frequently_messages_to_crelate(integration, day, limit, offset) do
    messages = Activities.list_whippy_messages_with_the_gap_of_inactivity(integration, limit, offset)

    if Enum.count(messages) < limit do
      sync_daily_whippy_contact_messages_to_crelate(integration, day, messages)
    else
      sync_daily_whippy_contact_messages_to_crelate(integration, day, messages)

      bulk_push_frequently_messages_to_crelate(integration, day, limit, offset + limit)
    end
  end

  def bulk_push_daily_messages_to_crelate(integration, day, limit, offset) do
    timezone = integration.settings["timezone"] || @default_timezone
    messages = Activities.list_daily_whippy_messages_with_timezone(integration, day, limit, offset, timezone)

    if Enum.count(messages) < limit do
      sync_daily_whippy_contact_messages_to_crelate(integration, day, messages)
    else
      sync_daily_whippy_contact_messages_to_crelate(integration, day, messages)

      bulk_push_daily_messages_to_crelate(integration, day, limit, offset + limit)
    end
  end

  defp sync_daily_whippy_contact_messages_to_crelate(integration, day, messages) do
    messages
    |> Enum.group_by(& &1.external_contact_id)
    |> Enum.each(fn {contact_id, messages} ->
      contact = Contacts.get_contact_by_external_id(integration.id, contact_id)

      if contact do
        Logger.info(
          "[Crelate] [Daily #{day}] Syncing #{Enum.count(messages)} messages for contact #{contact.name} to Crelate"
        )
      end

      sync_daily_messages_to_crelate(messages, contact, integration, contact_id)
    end)
  end

  defp sync_daily_messages_to_crelate([], _contact, _integration, _employee_id), do: []

  defp sync_daily_messages_to_crelate(_messages, nil, _integration, _employee_id), do: []

  defp sync_daily_messages_to_crelate(messages, contact, integration, contact_id) do
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
      |> Enum.chunk_every(100)
      |> Enum.map(fn messages_chunk ->
        sync_args = %{
          messages_chunk: messages_chunk,
          conversation_id: conversation_id,
          integration: integration,
          contact: contact,
          contact_id: contact_id
        }

        sync_daily_message_chunk_to_crelate(sync_args)
      end)
    end)
  end

  defp sync_daily_message_chunk_to_crelate(%{messages_chunk: []}), do: []

  defp sync_daily_message_chunk_to_crelate(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         contact_id: contact_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)
    conversation_link = generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "", fn message, acc ->
        Workers.Utils.build_message_body_for_crelate(message, acc, contact, integration)
      end)

    message_body_with_link = message_body <> "<a href='#{conversation_link}'>View Message</a>"

    message_body_with_link
    |> sync_message_to_crelate(integration, contact_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  ##################
  ##   Messages   ##
  ##  (full sync) ##
  ##################

  @spec bulk_push_messages_to_crelate(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Activity.t()]
  def bulk_push_messages_to_crelate(integration, limit, offset) do
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    synced_result =
      Enum.map(contacts, fn contact ->
        sync_all_time_whippy_contact_messages_to_crelate(
          integration,
          contact
        )
      end)

    if Enum.count(contacts) < limit do
      synced_result
    else
      bulk_push_messages_to_crelate(integration, limit, offset + limit)
    end
  end

  defp sync_all_time_whippy_contact_messages_to_crelate(
         integration,
         %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: contact_id} = contact
       ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    Logger.info("Syncing #{Enum.count(messages)} messages for contact #{contact.name} to Crelate")

    sync_all_time_messages_to_crelate(messages, contact, integration, contact_id)
  end

  defp sync_all_time_messages_to_crelate([], _contact, _integration, _contact_id), do: []

  defp sync_all_time_messages_to_crelate(messages, contact, integration, contact_id) do
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
            contact_id: contact_id
          }

          sync_message_chunk_to_crelate(sync_args)
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
            contact_id: contact_id
          }

          sync_message_chunk_to_crelate(sync_args)
        end)

      backdated_activities ++ today_activities
    end)
  end

  defp sync_message_chunk_to_crelate(%{messages_chunk: []}), do: []

  defp sync_message_chunk_to_crelate(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         contact_id: contact_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)

    conversation_link =
      Workers.Utils.generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "", fn message, acc ->
        Workers.Utils.build_message_body_for_crelate(message, acc, contact, integration, "<br/><br/>")
      end)

    message_body_with_link = message_body <> "<a href='#{conversation_link}'>View Message</a>"

    message_body_with_link
    |> sync_message_to_crelate(integration, contact_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  defp sync_message_to_crelate(message_body, integration, contact_id) do
    %Integration{
      authentication: %{"external_api_key" => api_key},
      settings: %{"crelate_messages_action_id" => message_action_id}
    } = integration

    case message_action_id do
      nil ->
        case Clients.Crelate.get_whippy_sms_id(api_key, integration.settings["use_production_url"]) do
          {:ok, message_id} ->
            Integrations.update_integration(integration, %{settings: %{"crelate_messages_action_id" => message_id}})

            crelate_message_body = prepare_crelate_message_body(message_body, contact_id, message_id)

            Clients.Crelate.create_contact_message(
              api_key,
              crelate_message_body,
              integration.settings["use_production_url"]
            )

          {:error, _reason} ->
            {:error, :invalid_message_action_id}
        end

      message_action_id ->
        crelate_message_body = prepare_crelate_message_body(message_body, contact_id, message_action_id)

        Clients.Crelate.create_contact_message(
          api_key,
          crelate_message_body,
          integration.settings["use_production_url"]
        )
    end
  end

  ##################
  ##   Messages   ##
  ##  (helpers) ##
  ##################

  defp prepare_crelate_message_body(message_body, contact_id, message_action_id) do
    %{
      entity: %{
        Display: message_body,
        HTML: message_body,
        ParentId: %{
          Id: contact_id,
          EntityName: "Contacts"
        },
        VerbId: %{
          Id: message_action_id
        }
      }
    }
  end

  defp save_external_activity_to_activity_records({:error, :invalid_message_action_id} = error, _activities) do
    error
  end

  defp save_external_activity_to_activity_records(response, activities) do
    case response do
      {:ok, %{"messageId" => external_activity_id} = external_activity} ->
        Enum.map(activities, fn activity ->
          Activities.update_activity_synced_in_external_integration(
            activity,
            "#{external_activity_id}",
            external_activity
          )
        end)

      error ->
        error_log = inspect(error)
        Logger.error("Error syncing Crelate activity: #{error_log}")

        Enum.each(activities, fn activity ->
          Utils.log_activity_error(activity, "integration", error_log)
        end)

        error
    end
  end

  defp generate_conversation_link(message_id, conversation_id, organization_id) do
    whippy_dashboard_url = Application.get_env(:sync, :whippy_dashboard)

    "#{whippy_dashboard_url}/organizations/#{organization_id}/all/open/#{conversation_id}?message_id=#{message_id}"
  end

  defp extract_first_message_id([%Activity{whippy_activity: %{"id" => message_id}} | _]) do
    message_id
  end
end
