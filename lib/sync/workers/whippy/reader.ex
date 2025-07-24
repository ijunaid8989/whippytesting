defmodule Sync.Workers.Whippy.Reader do
  @moduledoc """
  Contains utility functions reused across workers,
  related to reading data from Whippy.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Channels
  alias Sync.Channels.Channel
  alias Sync.Clients
  alias Sync.Clients.Whippy
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Integrations.User

  require Logger

  @type iso_8601_date :: String.t()

  @default_conversations_limit 30
  @default_conversations_offset 0

  @default_messages_limit 50
  @default_messages_offset 0
  @default_timezone "Etc/GMT"

  @spec pull_whippy_contacts(
          Integration.t(),
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_whippy_contacts(%Integration{} = integration, day, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.list_contacts(api_key,
           created_at: [before: "#{day}T23:59:59Z", after: "#{day}T00:00:00Z"],
           limit: limit,
           offset: offset
         ) do
      {:ok, %{contacts: contacts}} when length(contacts) < limit ->
        Contacts.save_whippy_contacts(integration, contacts)

      {:ok, %{contacts: contacts}} ->
        Contacts.save_whippy_contacts(integration, contacts)

        pull_whippy_contacts(integration, limit, offset + limit)
    end
  end

  @spec pull_whippy_contacts(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_whippy_contacts(%Integration{} = integration, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.list_contacts(api_key, limit: limit, offset: offset) do
      {:ok, %{contacts: contacts}} when length(contacts) < limit ->
        Contacts.save_whippy_contacts(integration, contacts)

      {:ok, %{contacts: contacts}} ->
        Contacts.save_whippy_contacts(integration, contacts)

        pull_whippy_contacts(integration, limit, offset + limit)

      {:error, error} ->
        Logger.error("Error saving Whippy contacts: #{inspect(error)}")

        {:error, error}
    end
  end

  @spec get_contact_by_id(Integration.t(), String.t()) :: {:ok, list()}
  def get_contact_by_id(integration, whippy_contact_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.get_contact(api_key, whippy_contact_id) do
      {:ok, contact} ->
        Contacts.save_whippy_contacts(integration, [contact])

      {:error, error} ->
        Logger.error("Error saving Whippy contacts: #{inspect(error)}")

        {:error, error}
    end
  end

  ##################
  ##   Messages   ##
  ## (daily sync) ##
  ##################

  @doc """
  Saves Whippy messages for an organization (based on Whippy API key) for a given day in the Sync database.

  To accomplish this, we have to make a request to list all conversations that have
  last_message_date as the specified time span, then for each conversations make requests for all messages
  created_at during that span, in chunks, and insert them.

  We want to query for all messages with an overlap of 12 hours just in case,
  therefore we use a time span of 36 hours.

  IMPORTANT: The conversation's `last_message_date` field can always be pushed ahead
  if there are constantly new messages. For this reason, we always have to use a `before` time
  that is the current time, in order to not miss messages.

  Therefore we operate on several different nested lists here.
  """
  @spec pull_daily_whippy_messages(
          Integration.t(),
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          [
            [
              {:ok, [[{:ok, Activity.t()}]]}
              | {:error, any()}
            ]
          ]
          | nil
  def pull_daily_whippy_messages(%Integration{} = integration, iso_day, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    four_days_ago =
      iso_day
      |> Date.from_iso8601!()
      |> Date.add(-4)

    time_now = DateTime.to_iso8601(DateTime.utc_now())

    case Whippy.list_conversations(api_key,
           last_message_date: [before: time_now, after: "#{four_days_ago}T12:00:00Z"],
           limit: limit,
           offset: offset
         ) do
      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and conversations != [] and length(conversations) < limit ->
        Enum.map(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = maybe_get_or_fetch_contact(integration.client, integration, conversation.contact_id)

          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and conversations != [] ->
        Enum.each(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = maybe_get_or_fetch_contact(integration.client, integration, conversation.contact_id)

          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

        pull_daily_whippy_messages(integration, iso_day, limit, offset + limit)

      {:ok, %{total: 0, conversations: []}} ->
        []

      unexpected_conversations_response ->
        Logger.error("Unexpected Whippy daily conversations response: #{inspect(unexpected_conversations_response)}")

        nil
    end
  end

  def maybe_get_or_fetch_contact(:tempworks, integration, whippy_contact_id) do
    case Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id) do
      nil ->
        fetch_contact_from_whippy_and_from_tempworks(integration, whippy_contact_id)

      contact ->
        if contact.external_contact_id != nil do
          contact
        else
          fetch_contact_from_whippy_and_from_tempworks(integration, whippy_contact_id)
        end
    end
  end

  def maybe_get_or_fetch_contact(:aqore, integration, whippy_contact_id) do
    case Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id) do
      nil ->
        fetch_contact_from_whippy_and_from_aqore(integration, whippy_contact_id)

      contact ->
        if contact.external_contact_id != nil do
          contact
        else
          fetch_contact_from_whippy_and_from_aqore(integration, whippy_contact_id)
        end
    end
  end

  def maybe_get_or_fetch_contact(_integration, integration, whippy_contact_id) do
    Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id)
  end

  defp fetch_contact_from_whippy_and_from_tempworks(integration, whippy_contact_id) do
    with {:ok, _count} <- get_contact_by_id(integration, whippy_contact_id),
         contact when not is_nil(contact) <- Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id),
         {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} <-
           Authentication.Tempworks.get_or_regenerate_service_token(integration) do
      Sync.Workers.Tempworks.Reader.get_employee_from_tempwork_and_update_to_sync(integration, access_token, contact)
      Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id)
    else
      _error ->
        nil
    end
  end

  defp fetch_contact_from_whippy_and_from_aqore(integration, whippy_contact_id) do
    with {:ok, _count} <- get_contact_by_id(integration, whippy_contact_id),
         contact when not is_nil(contact) <- Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id) do
      Sync.Workers.Aqore.Reader.get_and_update_candidate(integration, contact)
      Contacts.get_contact_by_whippy_id(integration.id, whippy_contact_id)
    else
      _error ->
        nil
    end
  end

  # TODO: deprecate, in favor of pull_daily_whippy_messages/4
  def bulk_pull_daily_whippy_messages(integration, day, limit, offset) do
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    if Enum.count(contacts) < limit do
      pull_daily_whippy_messages(integration, contacts, day, @default_conversations_limit, @default_conversations_offset)
    else
      pull_daily_whippy_messages(integration, contacts, day, @default_conversations_limit, @default_conversations_offset)

      bulk_pull_daily_whippy_messages(integration, day, limit, offset + limit)
    end
  end

  @doc """
  Saves Whippy messages for a list of contacts for a given day in the Sync database.

  To accomplish this, we have to make a request to list all of the contacts' conversations that have
  last_message_date as the specified day, then for each conversations make requests for all messages
  created_at during that day, in chunks, and insert them.

  We want to query for all messages with an overlap of 12 hours just in case,
  therefore we use a time span of 36 hours.

  IMPORTANT: The conversation's `last_message_date` field can always be pushed ahead
  if there are constantly new messages. For this reason, we always have to use a `before` time
  that is the current time, in order to not miss messages.

  Therefore we operate on several different nested lists here.
  """
  @spec pull_daily_whippy_messages(
          Integration.t(),
          [Contact.t()],
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          [
            [
              {:ok, [[{:ok, Activity.t()}]]}
              | {:error, any()}
            ]
          ]
          | nil
  def pull_daily_whippy_messages(%Integration{} = integration, contacts, iso_day, limit, offset)
      when is_list(contacts) and contacts != [] do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)
    contact_ids = Enum.map(contacts, & &1.whippy_contact_id)

    four_days_ago =
      iso_day
      |> Date.from_iso8601!()
      |> Date.add(-4)

    time_now = DateTime.to_iso8601(DateTime.utc_now())

    case Whippy.list_conversations(api_key,
           contact_ids: contact_ids,
           last_message_date: [before: time_now, after: "#{four_days_ago}T12:00:00Z"],
           limit: limit,
           offset: offset
         ) do
      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and conversations != [] and length(conversations) < limit ->
        Enum.map(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = Enum.find(contacts, fn contact -> contact.whippy_contact_id == conversation.contact_id end)

          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and conversations != [] ->
        Enum.each(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = Enum.find(contacts, fn contact -> contact.whippy_contact_id == conversation.contact_id end)

          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

        pull_daily_whippy_messages(integration, contacts, iso_day, limit, offset + limit)

      {:ok, %{total: 0, conversations: []}} ->
        []

      unexpected_conversations_response ->
        Logger.error("Unexpected Whippy daily conversations response: #{inspect(unexpected_conversations_response)}")

        nil
    end
  end

  @doc """
  DEPRECATED

  Saves Whippy messages for a given contact for a given day in the Sync database.

  To accomplish this, we have to make a request to list all of the contact's conversations that have
  last_message_date as the specified day, then for each conversations make requests for all messages
  created_at during that day, in chunks, and insert them.

  Therefore we operate on several different nested lists here.
  """
  @spec pull_contact_daily_whippy_messages(
          Integration.t(),
          Contact.t(),
          iso_8601_date(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          [
            [
              {:ok, [[{:ok, Activity.t()}]]}
              | {:error, any()}
            ]
          ]
          | nil
  def pull_contact_daily_whippy_messages(%Integration{} = integration, contact, iso_day, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    day = Date.from_iso8601!(iso_day)
    next_day = Date.add(day, 1)
    previous_day = Date.add(day, -2)

    case Whippy.list_conversations(api_key,
           contact_ids: [contact.whippy_contact_id],
           last_message_date: [before: "#{next_day}T00:00:00Z", after: "#{previous_day}T12:00:00Z"],
           limit: limit,
           offset: offset
         ) do
      {:ok, %{total: total, conversations: conversations}}
      when total >= 0 and length(conversations) < limit ->
        Enum.map(conversations, fn conversation ->
          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

      {:ok, %{total: total, conversations: conversations}}
      when total >= 0 and conversations != [] ->
        Enum.each(conversations, fn conversation ->
          pull_daily_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            iso_day,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

        pull_contact_daily_whippy_messages(integration, contact, iso_day, limit, offset + limit)

      unexpected_conversations_response ->
        Logger.error("Unexpected Whippy daily conversations response: #{inspect(unexpected_conversations_response)}")

        nil
    end
  end

  # we want to query for messages until the current time always
  # because otherwise we might miss some messages
  # it is best to save all in the Sync database
  # then filter on whippy_inserted_at timestamp when querying
  # to push them specifically when we want to
  defp pull_daily_whippy_conversation_messages(
         %Integration{} = integration,
         %Contact{} = contact,
         conversation_id,
         iso_day,
         message_limit,
         message_offset
       ) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    # revert to 2 days ago after first sync
    four_days_ago =
      iso_day
      |> Date.from_iso8601!()
      |> Date.add(-4)

    time_now = DateTime.to_iso8601(DateTime.utc_now())

    case Whippy.get_conversation(api_key, conversation_id,
           message_limit: message_limit,
           message_offset: message_offset,
           messages_created_at: [before: time_now, after: "#{four_days_ago}T12:00:00Z"]
         ) do
      {:ok, %Whippy.Model.Conversation{messages: messages} = _conversation}
      when length(messages) < message_limit ->
        Activities.save_whippy_messages(integration, contact, conversation_id, messages)

      {:ok, %Whippy.Model.Conversation{messages: messages} = _conversation} ->
        Activities.save_whippy_messages(integration, contact, conversation_id, messages)

        pull_daily_whippy_conversation_messages(
          integration,
          contact,
          conversation_id,
          iso_day,
          message_limit,
          message_offset + message_limit
        )

      unexpected_messages_response ->
        Logger.error("Unexpected Whippy messages response: #{inspect(unexpected_messages_response)}")

        nil
    end
  end

  defp pull_daily_whippy_conversation_messages(
         _integration,
         _contact,
         _conversation_id,
         _iso_day,
         _message_limit,
         _message_offset
       ) do
    nil
  end

  ##################
  ##   Messages   ##
  ##  (full sync) ##
  ##################

  @doc """
  Recursively pulls Whippy messages for all contacts in the Sync database.

  ## Parameters
    - `integration` - the integration to use
    - `limit` - the number of contacts to pull messages for
    - `offset` - the offset to start pulling messages from

  ## Description
  This function pulls messages for all contacts in the Sync database in chunks of `limit` size.
  It will continue to pull messages until all contacts and all their conversations have been processed.
  """
  def bulk_pull_whippy_messages(integration, limit, offset) do
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    if Enum.count(contacts) < limit do
      pull_whippy_messages(integration, contacts, @default_conversations_limit, @default_conversations_offset)
    else
      pull_whippy_messages(integration, contacts, @default_conversations_limit, @default_conversations_offset)

      bulk_pull_whippy_messages(integration, limit, offset + limit)
    end
  end

  @doc """
  Saves Whippy messages for a given list of contacts in the Sync database.

  To accomplish this, we have to make a request to list all of the contacts' conversations,
  then for each conversations make requests for all messages in chunks, and insert them.

  Therefore we operate on several different nested lists here.
  """

  @spec pull_whippy_messages(Integration.t(), [Contact.t()], non_neg_integer(), non_neg_integer()) ::
          [
            [
              {:ok, [[{:ok, Activity.t()}]]}
              | {:error, any()}
            ]
          ]
          | nil
  def pull_whippy_messages(%Integration{} = integration, contacts, limit, offset)
      when is_list(contacts) and contacts != [] do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)
    contact_ids = Enum.map(contacts, & &1.whippy_contact_id)

    case Whippy.list_conversations(api_key,
           contact_ids: contact_ids,
           limit: limit,
           offset: offset
         ) do
      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and length(conversations) < limit ->
        Enum.map(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = Enum.find(contacts, fn contact -> contact.whippy_contact_id == conversation.contact_id end)

          pull_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

      {:ok, %{total: total, conversations: conversations}}
      when total > 0 and conversations != [] ->
        Enum.each(conversations, fn conversation ->
          # NOTE: Once we have many-to-many conversations and contacts
          # we will have to update this
          contact = Enum.find(contacts, fn contact -> contact.whippy_contact_id == conversation.contact_id end)

          pull_whippy_conversation_messages(
            integration,
            contact,
            conversation.id,
            @default_messages_limit,
            @default_messages_offset
          )
        end)

        pull_whippy_messages(integration, contacts, limit, offset + limit)

      {:ok, %{total: 0, conversations: []}} ->
        []

      unexpected_conversations_response ->
        Logger.error("Unexpected Whippy conversations response: #{inspect(unexpected_conversations_response)}")

        nil
    end
  end

  @spec pull_whippy_messages(Integration.t(), Contact.t(), non_neg_integer(), non_neg_integer()) ::
          [
            [
              {:ok, [{non_neg_integer(), nil}]}
              | {:error, any()}
              | Ecto.Multi.failure()
            ]
          ]
          | nil
  defp pull_whippy_conversation_messages(
         %Integration{} = integration,
         contact,
         conversation_id,
         message_limit,
         message_offset
       ) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.get_conversation(api_key, conversation_id,
           message_limit: message_limit,
           message_offset: message_offset
         ) do
      {:ok, %Whippy.Model.Conversation{messages: messages} = _conversation}
      when length(messages) < message_limit ->
        Activities.save_whippy_messages(integration, contact, conversation_id, messages)

      {:ok, %Whippy.Model.Conversation{messages: messages} = _conversation} ->
        Activities.save_whippy_messages(integration, contact, conversation_id, messages)

        pull_whippy_conversation_messages(
          integration,
          contact,
          conversation_id,
          message_limit,
          message_offset + message_limit
        )

      unexpected_messages_response ->
        Logger.error("Unexpected Whippy messages response: #{inspect(unexpected_messages_response)}")

        nil
    end
  end

  ##################
  ##   Channels   ##
  ##################

  def save_channel_and_get_timezone(integration, whippy_organization_id, whippy_channel_id) do
    case Channels.get_integration_whippy_channel(integration.id, whippy_channel_id) do
      %Channel{timezone: timezone} ->
        timezone || @default_timezone

      nil ->
        save_whippy_channel_and_infer_timezone(integration, whippy_organization_id, whippy_channel_id) ||
          @default_timezone
    end
  end

  @spec get_channel(Integration.t(), Ecto.UUID.t()) :: Whippy.Model.Channel.t() | nil
  def get_channel(integration, whippy_channel_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.get_channel(api_key, whippy_channel_id) do
      {:ok, %Whippy.Model.Channel{} = whippy_channel} ->
        whippy_channel

      _error ->
        nil
    end
  end

  def get_contact_channel(integration, contact, conversations_limit, conversations_offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Clients.Whippy.list_conversations(api_key,
           contact_ids: [contact.whippy_contact_id],
           limit: conversations_limit,
           offset: conversations_offset
         ) do
      {:ok, %{total: total, conversations: conversations}}
      when total >= 0 and length(conversations) < conversations_limit ->
        Enum.find_value(conversations, nil, fn conversation ->
          # map conversation.channel_id to Sync whippy_channel_id (with non-null external_channel_id)
          Channels.get_integration_whippy_channel(integration.id, conversation.channel_id)
        end)

      {:ok, %{total: total, conversations: conversations}}
      when total >= 0 and conversations != [] ->
        channel =
          Enum.find_value(conversations, nil, fn conversation ->
            # map conversation.channel_id to Sync whippy_channel_id (with non-null external_channel_id)
            Channels.get_integration_whippy_channel(integration.id, conversation.channel_id)
          end)

        # if no synced channel is found and there are more results, continue
        channel ||
          get_contact_channel(integration, contact, conversations_limit, conversations_offset + conversations_limit)

      unexpected_conversations_response ->
        Logger.error("Unexpected Whippy contact conversations response: #{inspect(unexpected_conversations_response)}")

        nil
    end
  end

  defp save_whippy_channel_and_infer_timezone(
         %Integration{id: integration_id} = integration,
         whippy_organization_id,
         whippy_channel_id
       ) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.get_channel(api_key, whippy_channel_id) do
      {:ok, %Whippy.Model.Channel{} = whippy_channel} ->
        parsed_channel = Whippy.Parser.convert_channel_to_sync_channel(whippy_channel)

        attrs =
          Map.merge(parsed_channel, %{
            integration_id: integration_id,
            whippy_organization_id: whippy_organization_id
          })

        {:ok, %Channel{timezone: timezone}} = Channels.create_whippy_channel(attrs)

        timezone

      _error ->
        nil
    end
  end

  ###############
  ##   Users   ##
  ###############

  @spec pull_whippy_users(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_whippy_users(integration, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Clients.Whippy.list_users(api_key, limit: limit, offset: offset) do
      {:ok, %{total: _, users: users}} when length(users) < limit ->
        integration |> Integrations.save_whippy_users(users) |> log_error(integration, limit, offset)

      {:ok, %{total: _, users: users}} ->
        integration |> Integrations.save_whippy_users(users) |> log_error(integration, limit, offset)

        pull_whippy_users(integration, limit, offset + limit)

      {:error, reason} ->
        Logger.error(
          "[Whippy] [#{integration.id}] Error pulling users with limit #{limit} and offset #{offset} from Whippy. Skipping batch. Error: #{inspect(reason)}"
        )

        pull_whippy_users(integration, limit, offset + limit)
    end
  end

  def log_error({:error, reason}, integration, limit, offset) do
    Logger.error(
      "[Whippy] [#{integration.id}] Error saving users with limit #{limit} and offset #{offset} from Whippy. Skipping batch. Error: #{inspect(reason)}"
    )
  end

  def log_error(_result, _integration, _limit, _offset), do: :ok

  @doc """
  Retrieves the External ID of a Sync User from a Whippy message or conversation.

  ## Arguments
    - `integration` - the integration to use
    - `messages_chunk` - a list of messages
    - `conversation_id` - the Whippy conversation ID

  ## Returns
  - `{:ok, non_neg_integer()}` - the external user ID
  - `nil` - if no user is found

  """
  @spec get_external_user_id_by_whippy_messages_or_conversation(
          Integration.t(),
          list(),
          String.t()
        ) :: non_neg_integer() | nil
  def get_external_user_id_by_whippy_messages_or_conversation(integration, messages_chunk, conversation_id) do
    get_external_user_id_by_whippy_messages(integration, messages_chunk) ||
      get_external_user_id_by_whippy_conversation(integration, conversation_id) ||
      integration.authentication["fallback_external_user_id"]
  end

  defp get_external_user_id_by_whippy_messages(integration, messages_chunk) do
    whippy_user_id =
      Enum.find_value(messages_chunk, fn message ->
        message.whippy_user_id
      end)

    with true <- not is_nil(whippy_user_id),
         %User{external_user_id: external_id} when not is_nil(external_id) <-
           Integrations.get_user_by_whippy_id(integration.id, whippy_user_id) do
      String.to_integer(external_id)
    else
      _ -> nil
    end
  end

  defp get_external_user_id_by_whippy_conversation(integration, conversation_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    with {:ok, %Whippy.Model.Conversation{assigned_user_id: whippy_user_id}} when not is_nil(whippy_user_id) <-
           Whippy.get_conversation(api_key, conversation_id),
         %User{external_user_id: external_id} when not is_nil(external_id) <-
           Integrations.get_user_by_whippy_id(integration.id, whippy_user_id) do
      String.to_integer(external_id)
    else
      _ -> nil
    end
  end

  @doc """
  Retrieves a Sync User from a Whippy contact ID.

  ## Arguments
    - `integration` - the integration to use
    - `whippy_contact_id` - the Whippy contact ID to use

  ## Description
  First it finds a whippy conversation by the contact ID.
  If the conversation has an assigned user, it will use the whippy user ID to find the sync User.
  If not, it will find the first outbound message and return the whippy user ID associated with that message.
  If no user is found, it will return the fallback user specified in the integration's authentication.

  ## Returns
  - `{:ok, User.t()}` - the user found
  - nil - if no user is found

  """
  @spec get_user_by_whippy_contact_id(
          Integration.t(),
          non_neg_integer()
        ) :: {:ok, User.t()} | nil
  def get_user_by_whippy_contact_id(integration, whippy_contact_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)
    fallback_user_id = integration.authentication["fallback_external_user_id"]

    with {:ok, %{conversations: [conversation | _]}} <-
           Clients.Whippy.list_conversations(api_key, contact_ids: [whippy_contact_id]),
         %User{external_user_id: id} = user when not is_nil(id) <-
           get_user_from_whippy_conversation(integration, conversation) do
      user
    else
      _ -> Integrations.get_user_by_external_id(integration.id, integration.external_organization_id, fallback_user_id)
    end
  end

  defp get_user_from_whippy_conversation(integration, %Whippy.Model.Conversation{assigned_user_id: whippy_user_id})
       when not is_nil(whippy_user_id),
       do: Integrations.get_user_by_whippy_id(integration.id, whippy_user_id)

  defp get_user_from_whippy_conversation(integration, conversation) do
    case get_first_outbound_message(integration, conversation.id) do
      nil -> nil
      message -> Integrations.get_user_by_whippy_id(integration.id, message["user_id"])
    end
  end

  defp get_first_outbound_message(integration, conversation_id) do
    get_first_outbound_message_recursive(integration, conversation_id, @default_messages_limit, @default_messages_offset)
  end

  defp get_first_outbound_message_recursive(integration, conversation_id, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.get_conversation(api_key, conversation_id, message_limit: limit, message_offset: offset) do
      {:ok, %Whippy.Model.Conversation{messages: messages}} when length(messages) < limit ->
        find_outbound_message(messages)

      {:ok, %Whippy.Model.Conversation{messages: messages}} ->
        case get_first_outbound_message_recursive(integration, conversation_id, limit, offset + limit) do
          nil -> find_outbound_message(messages)
          message -> message
        end

      unexpected_messages_response ->
        Logger.error("Unexpected Whippy messages response: #{inspect(unexpected_messages_response)}")
        nil
    end
  end

  defp find_outbound_message(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find(&(Map.get(&1, :direction) == "outbound" && Map.get(&1, :user_id) != nil))
  end

  ####################
  ## Custom Objects ##
  ####################

  @spec pull_custom_objects(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_custom_objects(integration, limit, offset) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.list_custom_objects(api_key, limit: limit, offset: offset) do
      {:ok, %{total: _, custom_objects: custom_objects}} when length(custom_objects) < limit ->
        save_whippy_custom_objects(integration, custom_objects)

      {:ok, %{total: _, custom_objects: custom_objects}} ->
        save_whippy_custom_objects(integration, custom_objects)
        pull_custom_objects(integration, limit, offset + limit)
    end
  end

  defp save_whippy_custom_objects(integration, custom_objects) do
    Enum.map(custom_objects, fn custom_object ->
      custom_object
      |> Map.put(:integration_id, integration.id)
      |> Map.put(:whippy_organization_id, integration.whippy_organization_id)
      |> Contacts.create_custom_object_with_custom_properties()
    end)
  end
end
