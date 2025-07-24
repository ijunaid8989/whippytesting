defmodule Sync.Workers.Tempworks.Writer do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the TempWorks worker to sync TempWorks data from the Sync database
  to the TempWorks API.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Channels.Channel
  alias Sync.Clients
  alias Sync.Clients.Tempworks.Model.UniversalEmail
  alias Sync.Clients.Tempworks.Model.UniversalPhone
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Integrations.Integration
  alias Sync.Integrations.User
  alias Sync.Workers
  alias Sync.Workers.Utils

  require Logger

  @type error :: String.t()
  @type iso_8601_date :: String.t()

  @default_timezone "Etc/UTC"
  @us_country_code 840
  @initial_limit 100
  @initial_offset 0

  ##################
  ##   Contacts   ##
  ##################

  @spec push_contacts_to_tempworks(
          Integration.t(),
          iso_8601_date(),
          non_neg_integer()
        ) :: [{:ok, Contact.t()} | {:error, Ecto.Changeset.t()} | error()]
  def push_contacts_to_tempworks(integration, day, limit) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts =
      Contacts.daily_list_integration_contacts_missing_from_external_integration(
        integration,
        day,
        limit
      )

    if Enum.count(contacts) < limit do
      Enum.map(contacts, fn contact ->
        sync_individual_contact_to_tempworks(integration, access_token, contact)
      end)
    else
      Enum.each(contacts, fn contact ->
        sync_individual_contact_to_tempworks(integration, access_token, contact)
      end)

      push_contacts_to_tempworks(integration, day, limit)
    end
  end

  @spec push_contacts_to_tempworks(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [{:ok, Contact.t()} | {:error, Ecto.Changeset.t()} | error()]
  def push_contacts_to_tempworks(integration, limit) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts =
      Contacts.list_integration_contacts_missing_from_external_integration(integration, limit)

    if Enum.count(contacts) < limit do
      Enum.map(contacts, fn contact ->
        sync_individual_contact_to_tempworks(integration, access_token, contact)
      end)
    else
      Enum.each(contacts, fn contact ->
        sync_individual_contact_to_tempworks(integration, access_token, contact)
      end)

      push_contacts_to_tempworks(integration, limit)
    end
  end

  def sync_individual_contact_to_tempworks(integration, access_token, contact) do
    # throttle requests to avoid rate limiting which is 25 per 5 seconds
    :timer.sleep(200)

    case Workers.Whippy.Reader.get_contact_channel(integration, contact, @initial_limit, @initial_offset) do
      %Channel{external_channel: external_channel, external_channel_id: branch_id} when is_binary(branch_id) ->
        employee_payload =
          contact
          |> Clients.Tempworks.Parser.convert_contact_to_employee()
          |> Map.merge(%{
            branchId: branch_id,
            region: get_in(external_channel, ["address", "region"]) || integration.settings["tempworks_region"],
            countryCode: @us_country_code
          })

        get_contact_from_external_integration(
          access_token,
          employee_payload,
          integration,
          contact
        )

      nil ->
        Logger.error(
          "No branch found for contact #{contact.name} with ID #{contact.id} for integration #{integration.id}"
        )

        Utils.log_contact_error(contact, "integration", "No branch found for contact")

        nil

      error ->
        Logger.error(
          "Error fetching branch for contact #{contact.name} with ID #{contact.id} for integration #{integration.id}: #{inspect(error)}"
        )

        nil
    end
  end

  def get_contact_from_external_integration(
        access_token,
        %{primaryPhoneNumber: nil} = employee_payload,
        integration,
        contact
      ) do
    case Clients.Tempworks.get_employee_universal_email(access_token, employee_payload.primaryEmailAddress) do
      {:ok, []} ->
        create_employee_and_update_to_sync(access_token, employee_payload, integration, contact)

      {:ok, employee_list} ->
        check_and_update_contact_if_present(
          employee_list,
          contact,
          integration,
          access_token,
          employee_payload,
          UniversalEmail
        )

      {:error, error} ->
        Logger.error(
          "Error getting employee universal email  #{employee_payload.primaryEmailAddress} for contact #{contact.name}  integration #{integration.id}: #{inspect(error)}"
        )

        nil
    end
  end

  def get_contact_from_external_integration(access_token, employee_payload, integration, contact) do
    case get_employees_from_external_integration_using_phone(employee_payload, access_token) do
      {:ok, []} ->
        create_employee_and_update_to_sync(access_token, employee_payload, integration, contact)

      {:ok, employee_list} ->
        check_and_update_contact_if_present(
          employee_list,
          contact,
          integration,
          access_token,
          employee_payload,
          UniversalPhone
        )

      {:error, error} ->
        Logger.error(
          "Error getting employee universal phone  #{employee_payload.primaryPhoneNumber} for contact #{contact.name}  integration #{integration.id}: #{inspect(error)}"
        )

        nil
    end
  end

  # TODO: Move this to the Tempworks reader
  def get_employees_from_external_integration_using_phone(employee_payload, access_token) do
    phone_number_with_country_code = String.replace(employee_payload.primaryPhoneNumber, "+", "")
    phone_number_without_country_code = String.replace(employee_payload.primaryPhoneNumber, "+1", "")

    if String.length(phone_number_with_country_code) < 7 or String.length(phone_number_without_country_code) < 7 do
      {:error, "Invalid phone number length"}
    else
      with {:ok, emp_list_with_country_code} <-
             Clients.Tempworks.get_employee_universal_phone(access_token, phone_number_with_country_code),
           {:ok, emp_list_without_country_code} <-
             Clients.Tempworks.get_employee_universal_phone(access_token, phone_number_without_country_code) do
        {:ok, emp_list_with_country_code ++ emp_list_without_country_code}
      end
    end
  end

  defp check_and_update_contact_if_present(
         employee_list,
         contact,
         integration,
         access_token,
         employee_payload,
         struct_type
       ) do
    case Enum.find(employee_list, fn %^struct_type{firstName: first, lastName: last} ->
           "#{first} #{last}" == contact.name
         end) do
      nil ->
        # contact name is nil and phone number also nil, so here we are taking first map from list and updating the sync db
        if contact.name == nil do
          update_first_map_from_list_to_sync(employee_list, integration, contact)

          Logger.info(
            "Contact is #{contact.name} for email  #{employee_payload.primaryEmailAddress} phone #{employee_payload.primaryPhoneNumber} and integration #{integration.id}"
          )
        else
          create_employee_and_update_to_sync(access_token, employee_payload, integration, contact)
        end

      employee ->
        update_contact_synced_in_tempworks(
          :tempworks,
          integration,
          {:ok, %{"employeeId" => employee.employeeId}},
          contact,
          %{}
        )
    end
  end

  defp create_employee_and_update_to_sync(access_token, employee_payload, integration, contact) do
    first_name = Map.get(employee_payload, :firstName)
    last_name = Map.get(employee_payload, :lastName)

    if is_nil(first_name) or first_name == "" or is_nil(last_name) or last_name == "" do
      Logger.warning(
        "Skipped the contact to get create in Tempworks for integration #{integration.id} because First name is #{first_name} and Last name is #{last_name} for the phone #{employee_payload.primaryPhoneNumber} "
      )

      nil
    else
      employee_response = Clients.Tempworks.create_employee(access_token, employee_payload)

      update_contact_synced_in_tempworks(
        :tempworks,
        integration,
        employee_response,
        contact,
        %{}
      )
    end
  end

  def update_first_map_from_list_to_sync(employee_list, integration, contact) do
    employee_map =
      case Enum.find(employee_list, fn employee_struct -> employee_struct.isActive == true end) do
        nil -> List.first(employee_list)
        active_employee_map -> active_employee_map
      end

    sync_contact_update_params =
      %{}
      |> Map.put(:name, "#{employee_map.firstName} #{employee_map.lastName}")
      |> Map.put(:phone, contact.phone || employee_map.phoneNumber)

    update_contact_synced_in_tempworks(
      :tempworks,
      integration,
      {:ok,
       %{
         "employeeId" => employee_map.employeeId,
         "phone" => employee_map.phoneNumber,
         "name" => "#{employee_map.firstName} #{employee_map.lastName}",
         "isActive" => employee_map.isActive,
         "isAssigned" => employee_map.isAssigned
       }},
      contact,
      sync_contact_update_params
    )
  end

  defp update_contact_synced_in_tempworks(
         :tempworks,
         integration,
         {:ok, %{"employeeId" => external_id} = external_contact},
         %Contact{} = contact,
         sync_contact_update_params
       ) do
    Contacts.update_contact_synced_in_external_integration(
      integration,
      contact,
      external_id,
      external_contact,
      "employee",
      sync_contact_update_params
    )
  end

  defp update_contact_synced_in_tempworks(
         integration_type,
         integration,
         error,
         %Contact{name: name, id: id} = contact,
         _sync_contact_update_params
       ) do
    error_log = inspect(error)

    Logger.error(
      "Error syncing contact #{name} with ID #{id} to external #{integration_type} integration #{integration.id}: #{error_log}"
    )

    Utils.log_contact_error(contact, "integration", error_log)

    error
  end

  ##################
  ##   Messages   ##
  ##################

  ##################
  ##   Messages   ##
  ## (daily sync) ##
  ##################

  def bulk_push_frequently_messages_to_tempworks(integration, day, limit, offset) do
    messages = Activities.list_whippy_messages_with_the_gap_of_inactivity(integration, limit, offset)

    {:ok, %Integration{} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    if Enum.count(messages) < limit do
      sync_daily_whippy_contact_messages_to_tempworks(integration, day, messages)
    else
      sync_daily_whippy_contact_messages_to_tempworks(integration, day, messages)

      bulk_push_frequently_messages_to_tempworks(integration, day, limit, offset)
    end
  end

  def bulk_push_daily_messages_to_tempworks(integration, day, limit, offset) do
    timezone = integration.settings["timezone"] || @default_timezone

    messages = Activities.list_whippy_messages_before(integration, day, timezone, limit, offset)

    {:ok, %Integration{} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    if Enum.count(messages) < limit do
      sync_daily_whippy_contact_messages_to_tempworks(integration, day, messages)
    else
      sync_daily_whippy_contact_messages_to_tempworks(integration, day, messages)

      bulk_push_daily_messages_to_tempworks(integration, day, limit, offset)
    end
  end

  defp sync_daily_whippy_contact_messages_to_tempworks(integration, day, messages) do
    messages
    |> Enum.group_by(& &1.external_contact_id)
    |> Enum.each(fn {employee_id, messages} ->
      contact = Contacts.get_contact_by_external_id(integration.id, employee_id)

      if contact do
        Logger.info(
          "[TempWorks] [Daily #{day}] Syncing #{Enum.count(messages)} messages for contact #{contact.name} to TempWorks"
        )
      end

      sync_daily_messages_to_tempworks(messages, contact, integration, employee_id)
    end)
  end

  defp sync_daily_messages_to_tempworks([], _contact, _integration, _employee_id), do: []

  defp sync_daily_messages_to_tempworks(_messages, nil, _integration, _employee_id), do: []

  defp sync_daily_messages_to_tempworks(messages, contact, integration, employee_id) do
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
          employee_id: employee_id
        }

        sync_daily_message_chunk_to_tempworks(sync_args)
      end)
    end)
  end

  defp sync_daily_message_chunk_to_tempworks(%{messages_chunk: []}), do: []

  defp sync_daily_message_chunk_to_tempworks(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         contact: contact,
         employee_id: employee_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)
    conversation_link = generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "\n\n")
      end)

    message_body = "#{message_body} #{conversation_link}"

    message_body
    |> sync_daily_message_to_tempworks(integration, employee_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  defp sync_daily_message_to_tempworks(message_body, integration, employee_id) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    # throttle requests to avoid rate limiting which is 125 per 5 seconds
    # TODO: remove this when we implement tempworks rate limiting.
    :timer.sleep(200)

    case integration.settings do
      %{"tempworks_messages_action_id" => message_action_id} ->
        if String.starts_with?(employee_id, "contact-") do
          Clients.Tempworks.create_contact_message(
            access_token,
            employee_id,
            message_action_id,
            message_body
          )
        else
          Clients.Tempworks.create_employee_message(
            access_token,
            employee_id,
            message_action_id,
            message_body
          )
        end

      _invalid_message_settings ->
        {:error, :invalid_message_action_id}
    end
  end

  ##################
  ##   Messages   ##
  ##  (full sync) ##
  ##################

  def bulk_push_messages_to_tempworks(integration, limit, offset) do
    contacts = Contacts.list_integration_synced_contacts(integration, limit, offset)

    if Enum.count(contacts) < limit do
      Enum.map(contacts, fn contact ->
        sync_whippy_contact_messages_to_tempworks(integration, contact)
      end)
    else
      Enum.each(contacts, fn contact ->
        sync_whippy_contact_messages_to_tempworks(integration, contact)
      end)

      bulk_push_messages_to_tempworks(integration, limit, offset + limit)
    end
  end

  defp sync_whippy_contact_messages_to_tempworks(
         integration,
         %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: employee_id} = contact
       ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    # we still want to order by day when pushing to TempWorks
    # and we  can reuse the same interface here
    sync_daily_messages_to_tempworks(messages, contact, integration, employee_id)
  end

  defp sync_message_chunk_to_tempworks(%{messages_chunk: []}), do: []

  defp sync_message_chunk_to_tempworks(%{
         messages_chunk: messages_chunk,
         conversation_id: conversation_id,
         integration: integration,
         user: user,
         contact: contact,
         employee_id: employee_id
       }) do
    first_message_id = extract_first_message_id(messages_chunk)
    conversation_link = generate_conversation_link(first_message_id, conversation_id, integration.whippy_organization_id)

    message_body =
      Enum.reduce(messages_chunk, "#{conversation_link}\n\n", fn message, acc ->
        Workers.Utils.build_message_body(message, acc, contact, integration, "\n\n")
      end)

    message_body
    |> sync_message_to_tempworks(integration, user, employee_id)
    |> save_external_activity_to_activity_records(messages_chunk)
  end

  defp sync_message_to_tempworks(message_body, integration, %User{} = user, employee_id) do
    {:ok, %User{authentication: %{"access_token" => access_token}}} =
      Authentication.Tempworks.get_or_regenerate_user_token(user)

    # throttle requests to avoid rate limiting which is 25 per 5 seconds
    :timer.sleep(200)

    case integration.settings do
      %{"tempworks_messages_action_id" => message_action_id} ->
        Clients.Tempworks.create_employee_message(
          access_token,
          employee_id,
          message_action_id,
          message_body
        )

      _invalid_message_settings ->
        {:error, :invalid_message_action_id}
    end
  end

  #########################
  ##      Messages       ##
  ##   (sync with user)  ##
  #########################

  @doc """
  This function parses all messages for a given contact and syncs them to TempWorks.
  It also sets the user that sent the message in TempWorks, therefore it expects a user to be passed.

  Syncing to TempWorks works in chunks, therefore we return a chunk of records that were updated,
  where each record is an Activity, updated with the successful response from TempWorks.

  Or in case of a failed TempWorks request we return a string containing the error details.
  """
  @spec sync_whippy_contact_messages_to_tempworks_for_user(
          Integration.t(),
          User.t(),
          Contact.t()
        ) :: [[{:ok, Activity.t()} | {:error, Activity.t()} | error()]]
  def sync_whippy_contact_messages_to_tempworks_for_user(
        integration,
        %User{} = user,
        %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: employee_id} = contact
      ) do
    messages =
      Activities.list_whippy_contact_messages_missing_from_external_integration(
        integration,
        whippy_contact_id
      )

    sync_user_messages_to_tempworks(messages, contact, integration, user, employee_id)
  end

  defp sync_user_messages_to_tempworks([], _contact, _integration, _user, _employee_id), do: []

  defp sync_user_messages_to_tempworks(messages, contact, integration, %User{} = user, employee_id) do
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
          user: user,
          contact: contact,
          employee_id: employee_id
        }

        sync_message_chunk_to_tempworks(sync_args)
      end)
    end)
  end

  ##################
  ##   Messages   ##
  ##   (helpers)  ##
  ##################

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
        Logger.error("Error syncing Tempworks activity: #{error_log}")

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
