defmodule Sync.Webhooks.Tempworks do
  @moduledoc """
  Process Tempworks webhook events and manage webhook subscriptions.

  This module handles:
  - Subscribing to Tempworks webhook topics
  - Managing existing webhook subscriptions
  - Updating integration settings with subscription IDs
  - Processing webhook events for employees, assignments and custom data
  - Syncing data between Tempworks and Whippy

  ## Webhook Event Types
  - employee.created/updated - Employee creation/updates
  - employee.addressupdated - Employee address updates
  - employee.custompropertyupdated - Employee custom property updates
  - assignment.created/updated - Assignment creation/updates
  - assignment.custompropertyupdated - Assignment custom property updates
  """

  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Clients.Tempworks.Parser
  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Tempworks.Reader
  alias Sync.Workers.Whippy

  require Logger

  @parser_module Sync.Clients.Tempworks.Parser
  @default_call_back_url "https://sync.whippy.co/webhooks/v1/tempworks"
  # @default_call_back_url "https://gratefully-quiet-lobster.ngrok-free.app/webhooks/v1/tempworks"
  @client :tempworks

  @doc """
  Processes incoming webhook events from Tempworks.

  Takes the event payload and whippy organization ID and routes to appropriate handler.

  ## Parameters
    - event: map() - The webhook event payload containing eventName and payload
    - whippy_organization_id: String.t() - The Whippy organization ID

  ## Returns
    - {:ok, :processed} - Event processed successfully
    - {:error, reason} - Processing failed with reason

  ## Examples

      iex> process_event(%{"eventName" => "employee.created", "payload" => payload}, "org_123")
      {:ok, :processed}

      iex> process_event(%{"eventName" => "unknown", "payload" => payload}, "org_123")
      {:error, :unhandled_event}

      iex> process_event(%{"eventName" => "employee.created"}, "invalid_org")
      {:error, :integration_not_found}
  """
  @spec process_event(map(), String.t()) :: {:ok, :processed} | {:error, atom()}
  def process_event(%{"eventName" => event_name, "payload" => payload} = event, whippy_organization_id)
      when is_binary(whippy_organization_id) and is_map(payload) do
    Logger.info("[Tempworks Webhook] Processing  event #{event_name} payload #{inspect(payload)}")

    case Integrations.get_integration(whippy_organization_id, @client) do
      %Integration{} = integration ->
        Logger.info("[Tempworks Webhook] Processing event: #{event_name} for organization: #{whippy_organization_id}")
        process_event(integration, event_name, payload)

      nil ->
        Logger.error(
          "[Tempworks Webhook] Integration not found for event: #{inspect(event)} whippy_organization_id #{whippy_organization_id}"
        )

        {:error, :integration_not_found}
    end
  end

  def process_event(invalid_event, _org_id) do
    Logger.error("[Tempworks Webhook] Invalid event payload #{inspect(invalid_event)}")
    {:error, :invalid_payload}
  end

  @spec process_event(Integration.t(), String.t(), map()) :: {:ok, :processed} | {:error, any()}
  defp process_event(integration, event, %{"employeeId" => employee_id})
       when event in [
              "employee.updated",
              "employee.created",
              "employee.contactmethodcreated",
              "employee.contactmethodupdated",
              "employee.contactmethoddeleted"
            ] and is_integer(employee_id) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, employee_detail} <-
           Clients.Tempworks.get_employee(access_token, employee_id),
         {:ok, :synced} <- sync_employee(integration, employee_detail),
         {:ok, _} <- maybe_sync_employee_custom_object_record(integration, access_token, employee_id, employee_detail) do
      {:ok, :processed}
    else
      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync #{event} integration_id #{integration.id}, employee_id #{employee_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "employee.addressupdated", %{"employeeId" => employee_id} = payload)
       when is_integer(employee_id) do
    case sync_employee_address(integration, employee_id, payload) do
      {:ok, :synced} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync employee address update integration_id #{integration.id}, employee_id #{employee_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "employee.custompropertyupdated", %{"employeeId" => employee_id} = payload)
       when is_integer(employee_id) do
    case sync_employee_custom_property(integration, employee_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync employee Custom object integration_id #{integration.id}, employee_id #{employee_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, action, %{"assignmentId" => assignment_id} = payload)
       when action in ["assignment.created", "assignment.updated"] do
    case sync_assignment(integration, assignment_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process assignment create assignment_id #{assignment_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "assignment.custompropertyupdated", %{"assignmentId" => assignment_id} = payload) do
    case sync_assignment_custom_data(integration, assignment_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process assignment custom property assignment_id #{assignment_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, event, %{"contactId" => contact_id} = payload)
       when event in [
              "contact.updated",
              "contact.created",
              "contact.contactmethodcreated",
              "contact.contactmethodupdated",
              "contact.contactmethoddeleted"
            ] and is_integer(contact_id) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, {:ok, %{contacts: [contact_detail | _], total: _total_count}}} <-
           Clients.Tempworks.get_contact_search_by_id(access_token, contact_id),
         {:ok, :synced} <- sync_contact(integration, contact_detail, payload),
         {:ok, _} <- maybe_sync_contact_custom_object_record(integration, contact_id) do
      {:ok, :processed}
    else
      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync contact create/update integration_id #{integration.id}, contact_id #{contact_id} error #{inspect(reason)}"
        )

        error

      {:ok, {:ok, %{contacts: []}}} ->
        {:error, :contact_not_found}
    end
  end

  defp process_event(integration, "contact.addressupdated", %{"contactId" => contact_id} = payload)
       when is_integer(contact_id) do
    case sync_contact_address(integration, contact_id, payload) do
      {:ok, :synced} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync contact address update integration_id #{integration.id}, contact_id #{contact_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "contact.custompropertyupdated", %{"contactId" => contact_id} = payload)
       when is_integer(contact_id) do
    case sync_contact_custom_property(integration, contact_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to sync contact Custom object integration_id #{integration.id}, contact_id #{contact_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, action, %{"jobOrderId" => job_order_id} = payload)
       when action in ["joborder.created", "joborder.updated"] do
    case sync_job_order(integration, job_order_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process job order create job_order_id #{job_order_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "joborder.custompropertyupdated", %{"jobOrderId" => job_order_id} = payload) do
    case sync_job_order_custom_data(integration, job_order_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process job order custom property job_order_id #{job_order_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, action, %{"customerId" => customer_id} = payload)
       when action in ["customer.created", "customer.updated"] do
    case sync_customer(integration, customer_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process customer create customer_id #{customer_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, "customer.custompropertyupdated", %{"customerId" => customer_id} = payload) do
    case sync_customer_custom_data(integration, customer_id, payload) do
      {:ok, _} ->
        {:ok, :processed}

      {:error, reason} = error ->
        Logger.warning(
          "[Tempworks Webhook] Failed to process customer custom property customer_id #{customer_id}, integration_id #{integration.id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp process_event(integration, event_name, _payload) do
    Logger.warning("[Tempworks Webhook] Unhandled event type: #{event_name} integration #{integration.id}")
    {:error, :unhandled_event}
  end

  defp sync_assignment(integration, _assignment_id, payload) do
    assignment = Parser.parse_employee_assignment(payload)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "assignment"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             assignment
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for assignment.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_assignment_custom_data(integration, assignment_id, %{"propertyValues" => property_values}) do
    assignment =
      property_values
      |> Parser.parse_webhook_custom_data()
      |> append_assignment_id_in_custom_data(assignment_id)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "assignment"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             assignment,
             %{external_resource_id: assignment_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for assignment.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_employee_custom_property(integration, employee_id, %{"propertyValues" => property_values}) do
    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "employee"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         custom_data = Parser.parse_webhook_custom_data(property_values),
         custom_data = append_employee_id_in_custom_data(custom_data, employee_id),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             custom_data,
             %{external_resource_id: employee_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for employee.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_employee_address(integration, external_contact_id, %{"address" => address}) do
    # update address in contact,
    address = Parser.parse_webhook_address(address)

    attrs = %{
      external_contact_id: "#{external_contact_id}",
      address: address,
      external_organization_id: "#{integration.external_organization_id}"
    }

    with {:ok, contact} <- Contacts.upsert_external_contact(integration, attrs),
         :ok <- Whippy.Writer.send_contacts_to_whippy(@client, integration, [contact]) do
      {:ok, :synced}
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp sync_employee(integration, employee) do
    employee = Parser.convert_employee_detail_to_contact(employee, integration)
    Logger.info("[Tempworks Webhook] Syncing employee employee: #{inspect(employee)}")

    with {:ok, contact} <- Contacts.upsert_external_contact(integration, employee),
         _any =
           Reader.update_external_id_in_activities(integration, [employee]),
         :ok <- Whippy.Writer.send_contacts_to_whippy(@client, integration, [contact]) do
      {:ok, :synced}
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp sync_job_order(integration, _job_order, payload) do
    job_order = Parser.parse_webhook_job_order(payload)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "job_orders"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             job_order
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for job order.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_job_order_custom_data(integration, job_order_id, %{"propertyValues" => property_values}) do
    job_order =
      property_values
      |> Parser.parse_webhook_custom_data()
      |> append_job_order_id_in_custom_data(job_order_id)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "job_orders"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             job_order,
             %{external_resource_id: job_order_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for job order.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  def sync_customer(integration, _customer, payload) do
    customer = Parser.parse_webhook_customer(payload)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "customers"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             customer
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for customer.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  def sync_customer_custom_data(integration, customer_id, %{"propertyValues" => property_values}) do
    customer =
      property_values
      |> Parser.parse_webhook_custom_data()
      |> append_customer_id_in_custom_data(customer_id)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "customers"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             customer,
             %{external_resource_id: customer_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for customer.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_sync_employee_custom_object_record(
         %Integration{settings: %{"sync_custom_data" => true}} = integration,
         access_token,
         external_contact_id,
         parsed_employee
       ) do
    # parsed_employee = Parser.parse_employee_detail(employee)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "employee"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, contact} <- get_synced_contact(integration, external_contact_id),
         {:ok, employee_status} <-
           Clients.Tempworks.get_employee_status(access_token, contact.external_contact_id),
         {:ok, %{custom_data: custom_data_set}} <-
           Clients.Tempworks.get_employee_custom_data(access_token, contact.external_contact_id),
         filtered_custom_data = Enum.reject(custom_data_set, &(&1.propertyValue == nil)),
         {:ok, custom_object_record} <-
           Converter.convert_bulk_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             Reader.get_resources(parsed_employee, employee_status, filtered_custom_data),
             %{whippy_contact_id: contact.whippy_contact_id, external_resource_id: contact.external_contact_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[TempWorks Webhook] [Integration #{integration.id}] No custom object found for employee.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_sync_employee_custom_object_record(_, _, _, _), do: {:ok, :custom_object_disabled}

  defp maybe_sync_contact_custom_object_record(
         %Integration{settings: %{"sync_custom_data" => true}} = integration,
         external_contact_id
       ) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "tempworks_contacts"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         {:ok, contact} <- get_synced_tempwork_contact(integration, external_contact_id),
         {:ok, contact_detail} <-
           Clients.Tempworks.get_contact(access_token, external_contact_id),
         {:ok, %{custom_data: custom_data_set}} <-
           Clients.Tempworks.get_tempwork_contact_custom_data(access_token, contact.external_contact_id),
         filtered_custom_data = Enum.reject(custom_data_set, &(&1.propertyValue == nil)),
         {:ok, custom_object_record} <-
           Sync.Workers.CustomData.Converter.convert_bulk_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             Reader.get_resources(contact_detail, filtered_custom_data),
             %{
               whippy_contact_id: contact.whippy_contact_id,
               external_resource_id: "contact-#{contact.external_contact_id}"
             }
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[TempWorks Webhook] [Integration #{integration.id}] No custom object found for contact.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_sync_contact_custom_object_record(_, _), do: {:ok, :custom_object_disabled}

  defp append_employee_id_in_custom_data([], _employee_id), do: []

  defp append_employee_id_in_custom_data(custom_data_set, employee_id) do
    custom_data = %Clients.Tempworks.Model.WebhookCustomData{
      propertyValue: employee_id,
      propertyName: "employee_id"
    }

    [custom_data | custom_data_set]
  end

  defp append_assignment_id_in_custom_data([], _employee_id), do: []

  defp append_assignment_id_in_custom_data(custom_data_set, assignment_id) do
    custom_data = %Clients.Tempworks.Model.WebhookCustomData{
      propertyValue: assignment_id,
      propertyName: "assignment_id"
    }

    [custom_data | custom_data_set]
  end

  defp append_job_order_id_in_custom_data([], __job_order_id), do: []

  defp append_job_order_id_in_custom_data(custom_data_set, job_order_id) do
    custom_data = %Clients.Tempworks.Model.WebhookCustomData{
      propertyValue: job_order_id,
      propertyName: "job_order_id"
    }

    [custom_data | custom_data_set]
  end

  defp append_contact_id_in_custom_data([], _employee_id), do: []

  defp append_contact_id_in_custom_data(custom_data_set, contact_id) do
    custom_data = %Clients.Tempworks.Model.WebhookCustomData{
      propertyValue: contact_id,
      propertyName: "contact_id"
    }

    [custom_data | custom_data_set]
  end

  defp append_customer_id_in_custom_data([], __job_order_id), do: []

  defp append_customer_id_in_custom_data(custom_data_set, customer_id) do
    custom_data = %Clients.Tempworks.Model.WebhookCustomData{
      propertyValue: customer_id,
      propertyName: "customer_id"
    }

    [custom_data | custom_data_set]
  end

  defp get_synced_contact(integration, external_contact_id) do
    case Contacts.get_integration_synced_contact(integration, Integer.to_string(external_contact_id)) do
      nil -> {:error, :contact_not_found}
      contact -> {:ok, contact}
    end
  end

  defp get_synced_tempwork_contact(integration, external_contact_id) do
    case Contacts.get_integration_synced_contact(integration, "contact-" <> Integer.to_string(external_contact_id)) do
      nil -> {:error, :contact_not_found}
      contact -> {:ok, contact}
    end
  end

  defp sync_contact(integration, tempworks_contact, payload) do
    tempworks_contact = Parser.tempwork_contact_details_to_contact(tempworks_contact, payload, integration)
    Logger.info("[Tempworks Webhook] Syncing contact: #{inspect(tempworks_contact)}")
    # Check if contact has nil phone and assign phone if needed
    updated_tempworks_contact = maybe_assign_phone_to_contact(integration, tempworks_contact)

    with {:ok, contact} <- Contacts.upsert_external_contact(integration, updated_tempworks_contact),
         _any =
           Reader.update_external_id_in_activities(integration, [updated_tempworks_contact]),
         :ok <- Whippy.Writer.send_contacts_to_whippy(@client, integration, [contact]) do
      {:ok, :synced}
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_assign_phone_to_contact(integration, tempworks_contact) do
    case tempworks_contact.phone do
      nil ->
        Logger.info(
          "[Tempworks Webhook] Contact #{tempworks_contact.contact_id} has nil phone, attempting to assign phone from contact methods"
        )

        # Use the same logic as in Reader.maybe_check_phone_in_tempworks but for a single contact
        assign_phone_from_contact_methods(integration, tempworks_contact)

      _phone ->
        # Contact already has a phone, return as is
        tempworks_contact
    end
  end

  defp assign_phone_from_contact_methods(integration, contact) do
    phone_methods = get_contact_methods(integration, contact)

    case phone_methods do
      [] ->
        # No phone methods found, return contact unchanged
        Logger.warning("[Tempworks Webhook] No phone methods found for contact #{contact.contact_id}")
        contact

      methods when is_list(methods) ->
        # Choose the best phone method based on priority
        best_method = select_best_phone_method(methods)

        case best_method do
          nil ->
            Logger.warning("[Tempworks Webhook] No valid phone method found for contact #{contact.contact_id}")
            contact

          method ->
            phone_number = method["contactMethod"]

            Logger.info(
              "[Tempworks Webhook] Assigning phone #{phone_number} (#{method["contactMethodType"]}) to contact #{contact.contact_id}"
            )

            %{contact | phone: phone_number}
        end
    end
  end

  defp select_best_phone_method(phone_methods) do
    # Priority order: Cell Phone > Phone > Car Phone > Home Phone
    priority_order = ["Cell Phone", "Phone", "Car Phone", "Home Phone"]

    # Find the first method that matches our priority order
    priority_order
    |> Enum.find(fn priority_type ->
      Enum.any?(phone_methods, &(&1["contactMethodType"] == priority_type))
    end)
    |> then(fn priority_type ->
      Enum.find(phone_methods, &(&1["contactMethodType"] == priority_type))
    end)
    |> case do
      # Fallback to first method if no priority match
      nil -> List.first(phone_methods)
      method -> method
    end
  end

  defp get_contact_methods(integration, contact) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}}} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.get_contact_contact_methods(access_token, contact.contact_id) do
      {:ok, contact_methods} ->
        # Filter for phone-related contact methods
        filter_contact_methods(contact_methods)

      {:error, reason} ->
        Logger.error(
          "[Tempworks Webhook] Failed to fetch contact methods for contact #{contact.contact_id}: #{inspect(reason)}"
        )

        []
    end
  end

  def sync_contact_address(integration, external_contact_id, %{"address" => address}) do
    # update address in contact,
    address = Parser.parse_webhook_address(address)

    attrs = %{
      external_contact_id: "contact-#{external_contact_id}",
      address: address,
      external_organization_id: "#{integration.external_organization_id}"
    }

    with {:ok, contact} <- Contacts.upsert_external_contact(integration, attrs),
         :ok <- Whippy.Writer.send_contacts_to_whippy(@client, integration, [contact]) do
      {:ok, :synced}
    else
      {:error, _reason} = error ->
        error
    end
  end

  def sync_contact_custom_property(integration, contact_id, %{"propertyValues" => property_values}) do
    with custom_objects when is_list(custom_objects) and custom_objects != [] <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "tempworks_contacts"),
         %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
           List.first(custom_objects),
         custom_data = Parser.parse_webhook_custom_data(property_values),
         custom_data = append_contact_id_in_custom_data(custom_data, contact_id),
         {:ok, custom_object_record} <-
           Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             custom_data,
             %{external_resource_id: contact_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.warning("[Tempworks Webhook] [Integration #{integration.id}] No custom object found for contact.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Helper function to get a synced contact by external ID.

  ## Parameters
    - integration: Integration.t() - The integration record
    - external_contact_id: String.t() | integer() - External contact ID

  ## Returns
    - {:ok, %Integration{}} - Updated integration with subscription IDs
    - {:error, reason} - If subscription fails

  ## Examples

      iex> maybe_subscribe_to_webhooks(integration)
      {:ok, %Integration{settings: %{"webhooks" => [%{topic: "employee.created", subscription_id: 123}]}}}

  """
  def maybe_subscribe_to_webhooks(%Integration{settings: %{"webhooks" => webhooks}} = integration)
      when is_list(webhooks) and length(webhooks) > 0 do
    integration = Integrations.get_integration!(integration.id)

    token = get_token(integration)

    with {:ok, subscribed_topics} <- Clients.Tempworks.list_subscriptions(token),
         existing_subscribed_topics = Enum.map(webhooks, &process(&1, subscribed_topics, integration)),
         {:ok, _} <- update_webhook_settings(integration, existing_subscribed_topics) do
      updated_integration = Integrations.get_integration!(integration.id)
      {:ok, updated_integration}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to subscribe webhooks: #{inspect(error)}"}
    end
  end

  def maybe_subscribe_to_webhooks(%Integration{settings: settings}) do
    {:error, "No webhooks configured in integration settings: #{inspect(settings)}"}
  end

  def maybe_subscribe_to_webhooks(_) do
    {:error, "Invalid integration struct provided"}
  end

  @doc """
  Gets a valid access token for the integration.

  ## Returns
    - access_token: String - Valid access token
    - {:error, reason} - If token retrieval fails
  """
  def get_token(integration) do
    case Authentication.Tempworks.get_or_regenerate_service_token(integration) do
      {:ok, %Integration{authentication: %{"access_token" => access_token}}} ->
        access_token

      {:error, reason} ->
        Logger.error("[Tempworks Webhook] Failed to get access token: #{inspect(reason)}")
        {:error, "Failed to get access token"}
    end
  end

  @doc """
  Processes a webhook topic to ensure it is subscribed.

  Checks if topic exists in subscribed_topics, if not creates new subscription.

  ## Returns
    - %{topic: String, subscription_id: integer} - Topic and subscription mapping
  """
  def process(%{"topic" => topic}, subscribed_topics, integration) do
    case Enum.find(subscribed_topics, &(&1["topicName"] == topic and &1["callbackUrl"] == @default_call_back_url)) do
      nil ->
        case subscribe_topic_to_tempworks(topic, integration) do
          {:ok, subscription_id} ->
            %{topic: topic, subscription_id: subscription_id}

          {:error, reason} ->
            Logger.error("[Tempworks Webhook] Failed to subscribe topic #{topic}: #{inspect(reason)}")
            %{topic: topic, subscription_id: nil, error: reason}
        end

      subscription ->
        %{topic: topic, subscription_id: subscription["subscriptionId"]}
    end
  end

  def process(invalid_webhook, _subscribed_topics, _integration) do
    Logger.error("[Tempworks Webhook] Invalid webhook format: #{inspect(invalid_webhook)}")
    %{error: "Invalid webhook format"}
  end

  @doc """
  Subscribes a topic to Tempworks webhooks API.
  """
  def subscribe_topic_to_tempworks(topic, integration) do
    body = default_topic_params(topic, integration)

    integration
    |> get_token()
    |> Clients.Tempworks.subscribe_topic(body)
  end

  @doc """
  Builds default parameters for webhook topic subscription.
  """
  def default_topic_params(topic, integration) do
    %{
      "topicName" => topic,
      "callbackUrl" => @default_call_back_url,
      "callbackUrlIsSensitive" => false,
      "httpMethod" => "POST",
      "httpHeaderName" => "whippy_organization_id",
      "httpHeaderValue" => integration.whippy_organization_id,
      "httpHeaderValueIsSensitive" => false
    }
  end

  @doc """
  Updates integration settings with subscribed webhook topics.
  """
  def update_webhook_settings(integration, existing_subscribed_topics) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "webhooks", existing_subscribed_topics)
    Integrations.update_integration_settings(integration, %{settings: settings})
  end

  defp filter_contact_methods(contact_methods) do
    Enum.filter(contact_methods, fn method ->
      method["contactMethodType"] in ["Cell Phone", "Phone", "Car Phone", "Home Phone"]
    end)
  end
end
