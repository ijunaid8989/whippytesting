defmodule Sync.Workers.Tempworks.Reader do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the TempWorks worker to sync TempWorks data into the Sync database.
  """

  alias Sync.Activities
  alias Sync.Authentication
  alias Sync.Channels
  alias Sync.Clients
  alias Sync.Clients.Tempworks.Parser
  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Tempworks
  alias Sync.Workers.Whippy

  require Logger

  @client :tempworks
  @parser_module Sync.Clients.Tempworks.Parser
  @task_timeout :timer.seconds(300)
  @contact_prefix_pattern "contact-%"

  #####################################
  ##   Employees (Whippy Contacts)   ##
  #####################################

  @spec pull_employees(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_employees(integration, limit, offset) do
    branches_to_sync = fetch_branches_to_sync(integration)

    if branches_to_sync != [] do
      Enum.each(branches_to_sync, fn branch_id ->
        Logger.info("Pulling employees for branch #{branch_id} integration #{integration.id}")
        # Reset offset for each branch
        pull_employees_and_save(integration, limit, 0, branch_id)
      end)
    else
      pull_employees_and_save(integration, limit, offset)
    end
  end

  defp pull_employees_and_save(integration, limit, offset, branch_id \\ nil) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_employees(access_token,
           limit: limit,
           offset: offset,
           is_active: true,
           branch_id: branch_id
         ) do
      # we'll disregard total here just in case it is not equivalent to the length of the returned list
      {:ok, %{total: _total, employees: employees}} when length(employees) < limit ->
        Contacts.save_external_contacts(integration, employees)
        update_external_id_in_activities(integration, employees)

      {:ok, %{total: _total, employees: employees}} ->
        Contacts.save_external_contacts(integration, employees)
        update_external_id_in_activities(integration, employees)

        # Continue pagination for same branch
        pull_employees_and_save(integration, limit, offset + limit, branch_id)

      {:error, reason} ->
        Logger.error(
          "[TempWorks] [#{integration.id}] Error pulling employees with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # Continue pagination for same branch on error
        pull_employees_and_save(integration, limit, offset + limit, branch_id)
    end
  end

  def update_external_id_in_activities(integration, employees) do
    external_contact_ids_list = Enum.map(employees, fn employee -> employee.external_contact_id end)

    contacts_list =
      integration.id
      |> Contacts.list_whippy_contact_ids_for_all_external_contact_ids(external_contact_ids_list)
      |> Enum.reject(&is_nil(&1.whippy_contact_id))

    if contacts_list != [] do
      Logger.info("[TempWorks] [#{integration.id}] Updating activities for #{length(contacts_list)} contacts")
      Activities.update_activity_by_whippy_contact_id_in_bulk(contacts_list)
      Contacts.update_activity_contacts_by_whippy_contact_id_in_bulk(contacts_list)
    else
      Logger.info("[TempWorks] [#{integration.id}] No contacts found to update activities for")
    end
  end

  def process_todays_employees(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    {:ok, %{total: total, employee_ids: employee_ids}} = Clients.Tempworks.list_todays_employees(access_token)
    Logger.info("Processing #{total} employees for integration #{integration.id}")

    employee_ids
    |> Task.async_stream(
      fn employee_id ->
        process_each_employee(employee_id, integration)
      end,
      max_concurrency: 3,
      on_timeout: :kill_task,
      zip_input_on_exit: true,
      timeout: @task_timeout
    )
    |> Enum.to_list()
    |> log_task_results(integration.id, :employees)

    :ok
  end

  defp log_task_results(tasks, integration_id, entity_type) do
    Enum.each(tasks, fn
      {:exit, {input, reason}} = error ->
        Logger.error(
          "[Tempworks] [Integration #{integration_id}] Error syncing Sync #{entity_type} integration_id #{integration_id}, employee_id #{input.id} error #{inspect(reason)}"
        )

        error

      ok ->
        ok
    end)
  end

  def process_each_employee(employee_id, integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, employee_detail} <-
           Clients.Tempworks.get_employee(access_token, employee_id),
         {:ok, :synced} <- sync_employee(integration, employee_detail),
         {:ok, _} <- maybe_sync_employee_custom_object_record(integration, access_token, employee_id, employee_detail) do
      {:ok, :processed}
    else
      {:error, reason} = error ->
        Logger.error(
          "[Tempworks] Failed to sync employee integration_id #{integration.id}, employee_id #{employee_id} error #{inspect(reason)}"
        )

        error
    end
  end

  defp sync_employee(integration, employee) do
    employee = Parser.convert_employee_detail_to_contact(employee, integration)
    Logger.info("[Tempworks] Syncing employee employee: #{inspect(employee)}")

    with {:ok, contact} <- Contacts.upsert_external_contact(integration, employee),
         _any =
           Tempworks.Reader.update_external_id_in_activities(integration, [employee]),
         :ok <- Whippy.Writer.send_contacts_to_whippy(@client, integration, [contact]) do
      {:ok, :synced}
    else
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
             get_resources(parsed_employee, employee_status, filtered_custom_data),
             %{whippy_contact_id: contact.whippy_contact_id, external_resource_id: contact.external_contact_id}
           ),
         :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
      {:ok, :custom_object_synced}
    else
      [] ->
        Logger.error("[TempWorks] [Integration #{integration.id}] No custom object found for employee.")
        {:error, :no_custom_objects}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_sync_employee_custom_object_record(_, _, _, _), do: {:ok, :custom_object_disabled}

  defp get_synced_contact(integration, external_contact_id) do
    case Contacts.get_integration_synced_contact(integration, Integer.to_string(external_contact_id)) do
      nil -> {:error, :contact_not_found}
      contact -> {:ok, contact}
    end
  end

  def pull_advance_employees(integration, limit, offset) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    {:ok, data} = Clients.Tempworks.list_employee_columns(access_token)

    # Filter columns, which can't be queried.
    columns = process_column(data)

    do_pull_advance_employees(integration, columns, limit, offset)
  end

  def do_pull_advance_employees(integration, columns, limit, offset) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_employees_advance_details(access_token,
           limit: limit,
           offset: offset,
           columns: columns
         ) do
      # we'll disregard total here just in case it is not equivalent to the length of the returned list
      {:ok, %{total: _total, employees: employees}} when length(employees) < limit ->
        update_offset(:advance_employee_offset, integration, 0)
        Contacts.save_external_contacts(integration, employees)
        update_external_id_in_activities(integration, employees)

      {:ok, %{total: _total, employees: employees}} ->
        update_offset(:advance_employee_offset, integration, offset)
        Contacts.save_external_contacts(integration, employees)
        update_external_id_in_activities(integration, employees)
        do_pull_advance_employees(integration, columns, limit, offset + limit)

      {:error, reason} ->
        Logger.error(
          "[TempWorks] [#{integration.id}] Error pulling advance employees with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # skip batch and move to the next one
        do_pull_advance_employees(integration, columns, limit, offset + limit)
    end
  end

  def pull_contacts(integration, limit, offset) do
    Logger.info("[TempWorks] [#{integration.id}] Starting to pull contacts with limit #{limit} and offset #{offset}")

    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_contacts(access_token,
           limit: limit,
           offset: offset,
           is_active: true
         ) do
      # we'll disregard total here just in case it is not equivalent to the length of the returned list
      {:ok, %{total: _total, contacts: contacts}} when length(contacts) < limit ->
        Logger.info(
          "[TempWorks] [#{integration.id}] Found #{length(contacts)} contacts (final batch) with limit #{limit} and offset #{offset}"
        )

        updated_contacts = maybe_check_phone_in_tempworks(contacts, integration)
        Contacts.save_external_contacts(integration, updated_contacts)
        update_external_id_in_activities(integration, updated_contacts)

      {:ok, %{total: _total, contacts: contacts}} ->
        Logger.info(
          "[TempWorks] [#{integration.id}] Found #{length(contacts)} contacts with limit #{limit} and offset #{offset}"
        )

        updated_contacts = maybe_check_phone_in_tempworks(contacts, integration)
        Contacts.save_external_contacts(integration, updated_contacts)
        update_external_id_in_activities(integration, updated_contacts)
        pull_contacts(integration, limit, offset + limit)

      {:error, reason} ->
        Logger.error(
          "[TempWorks] [#{integration.id}] Error pulling contacts with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # skip batch and move to the next one
        pull_contacts(integration, limit, offset + limit)
    end
  end

  defp maybe_check_phone_in_tempworks(contacts, integration) do
    # Separate contacts with and without phones
    {contacts_with_phones, contacts_without_phones} = Enum.split_with(contacts, &(&1.phone != nil))

    Logger.info("[TempWorks] [#{integration.id}] Found #{length(contacts_without_phones)} contacts without phone numbers")

    # Process contacts without phones and assign phone numbers
    updated_contacts_without_phones =
      Enum.map(contacts_without_phones, fn contact -> assign_phone_from_contact_methods(integration, contact) end)

    # Combine all contacts (those with existing phones + those with newly assigned phones)
    contacts_with_phones ++ updated_contacts_without_phones
  end

  defp assign_phone_from_contact_methods(integration, contact) do
    phone_methods = get_contact_methods(integration, contact)

    case phone_methods do
      [] ->
        # No phone methods found, return contact unchanged
        Logger.debug(
          "[TempWorks] [#{integration.id}] No phone methods found for contact #{contact.contact_id}, keeping contact unchanged"
        )

        contact

      methods when is_list(methods) ->
        # Choose the best phone method based on priority
        best_method = select_best_phone_method(methods)

        case best_method do
          nil ->
            Logger.warning(
              "[TempWorks] [#{integration.id}] No valid phone method selected for contact #{contact.contact_id} despite having #{length(methods)} methods available"
            )

            contact

          method ->
            phone_number = method["contactMethod"]

            Logger.info(
              "[TempWorks] [#{integration.id}] Assigning phone #{phone_number} (#{method["contactMethodType"]}) to contact #{contact.contact_id}"
            )

            %{contact | phone: phone_number}
        end

      unexpected ->
        Logger.error(
          "[TempWorks] [#{integration.id}] Unexpected result from get_contact_methods for contact #{contact.contact_id}: #{inspect(unexpected)}"
        )

        contact
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
    case Authentication.Tempworks.get_or_regenerate_service_token(integration) do
      {:ok, %Integration{authentication: %{"access_token" => access_token}}} ->
        case Clients.Tempworks.get_contact_contact_methods(access_token, contact.contact_id) do
          {:ok, contact_methods} ->
            # Filter for phone-related contact methods
            filter_contact_methods(contact_methods)

          {:error, reason} ->
            Logger.error("""
            [TempWorks] [#{integration.id}] Error fetching contact methods for contact #{contact.contact_id} from TempWorks. Error: #{inspect(reason)}
            """)

            []
        end

      {:error, reason} ->
        Logger.error("""
        [TempWorks] [#{integration.id}] Error getting authentication token for contact #{contact.contact_id}. Error: #{inspect(reason)}
        """)

        []
    end
  end

  defp filter_contact_methods(contact_methods) do
    Enum.filter(contact_methods, fn method ->
      method["contactMethodType"] in ["Cell Phone", "Phone", "Car Phone", "Home Phone"]
    end)
  end

  defp process_column(data) do
    queryable_column = Enum.filter(data["data"], & &1["canBeIncludedInResults"])

    mapped_column = Enum.filter(queryable_column, &(&1["columnName"] in mapped_columns()))

    location_and_custom_data =
      Enum.filter(queryable_column, &(&1["category"] in ["Location", "Custom Data"]))

    dynamic_columns = Enum.map(mapped_column ++ location_and_custom_data, & &1["columnId"])
    Enum.uniq(dynamic_columns ++ required_column())
  end

  defp process_assignment_column(data) do
    dynamic_columns =
      data["data"]
      |> Enum.filter(& &1["canBeIncludedInResults"])
      |> Enum.map(& &1["columnId"])

    Enum.uniq(dynamic_columns ++ required_assignment_column())
  end

  # mapping of advance search and Employee Detail
  defp mapped_columns do
    [
      "EmployeeID",
      "BranchName",
      "CodeIdents",
      "InterestCode",
      "firstname",
      "lastname",
      "UserName",
      "active",
      "ActivationDate",
      "docname",
      "assigned",
      "I9Submitted",
      "I9Date",
      "aJobTitle",
      "Note",
      "Rating",
      "Email",
      "EnteredBySrident",
      "CustomerID",
      "CustName",
      "Identifier",
      "Employer",
      "PhoneNumber",
      "EmploymentStatusId",
      "Estatus",
      "CellPhone"
    ]
  end

  # column we are used for sorting in employees (names and status)
  defp required_column do
    [
      "f7daae6e-91c2-411e-9d94-2c6f17725eb4",
      "d14bf8a7-ba46-401d-8b7c-a264b117030a",
      "2a9ab5d8-a9d8-49c8-ae1c-17737471f860"
    ]
  end

  # column we are used for sorting in assignment (names and status)
  defp required_assignment_column do
    [
      "9739177b-d4a5-4593-a99f-9aea3fad003d",
      "7674fd28-8ae1-4608-a1f5-40aa4dfb0be5",
      "c9d2d4e9-aced-4b54-8328-efcd7c4a95f5"
    ]
  end

  @spec pull_employee_details(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_employee_details(parser_module, integration, custom_object, limit, offset) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts =
      Contacts.list_integration_synced_contacts_without_prefixing(integration, @contact_prefix_pattern, limit, offset)

    # filtered_contacts = Enum.reject(contacts, fn contact -> String.starts_with?(contact.external_contact_id, "contact-") end)

    Enum.each(contacts, fn contact ->
      with {:ok, employee_detail} <-
             Clients.Tempworks.get_employee(access_token, contact.external_contact_id),
           # Extract Birthday from Employee Detail & Save it in contact.
           employee = Parser.convert_employee_detail_to_contact(employee_detail, integration),
           {:ok, contact} <- Contacts.upsert_external_contact(integration, employee),
           {:ok, employee_status} <-
             Clients.Tempworks.get_employee_status(access_token, contact.external_contact_id),
           {:ok, %{custom_data: custom_data_set}} <-
             Clients.Tempworks.get_employee_custom_data(access_token, contact.external_contact_id),
           filtered_custom_data = Enum.reject(custom_data_set, &(&1.propertyValue == nil)),
           {:ok, %CustomObjectRecord{}} <-
             Sync.Workers.CustomData.Converter.convert_bulk_external_resource_to_custom_object_record(
               parser_module,
               integration,
               custom_object,
               get_resources(employee_detail, employee_status, filtered_custom_data),
               %{whippy_contact_id: contact.whippy_contact_id, external_resource_id: contact.external_contact_id}
             ) do
        :ok
      else
        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error converting employee detail for contact #{contact.id} with external_id #{contact.external_contact_id} from TempWorks. Skipping contact. Error: #{inspect(changeset)}
          """)

          :error

        {:error, reason} ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error pulling employee details for contact #{contact.id} with external_id #{contact.external_contact_id} from TempWorks. Skipping contact. Error: #{inspect(reason)}
          """)

          :error
      end
    end)

    if Enum.count(contacts) < limit do
      update_offset(:employee, integration, 0)
    else
      # lets set the offset when the current chunk has been finished.
      update_offset(:employee, integration, offset)
      pull_employee_details(parser_module, integration, custom_object, limit, offset + limit)
    end
  end

  def get_resources(resource, []), do: [resource]
  def get_resources(resource, custom_data), do: [resource, custom_data]

  def get_resources(resource, [], []), do: [resource]
  def get_resources(resource, employee_status, []), do: [resource, employee_status]
  def get_resources(resource, [], custom_data), do: [resource, custom_data]
  def get_resources(resource, employee_status, custom_data), do: [resource, employee_status, custom_data]
  # Soon to be deprecated
  @spec pull_employees_custom_data(
          atom(),
          Integration.t(),
          Ecto.UUID.generate(),
          CustomObject.t()
        ) :: :ok
  def pull_employees_custom_data(parser_module, integration, employee_custom_object_id, data_custom_object) do
    external_employee_ids =
      integration.id
      |> Contacts.list_external_ids_of_custom_object_records(employee_custom_object_id)
      |> Enum.map(&String.to_integer/1)

    do_pull_employees_custom_data(
      parser_module,
      integration,
      data_custom_object,
      external_employee_ids
    )
  end

  defp do_pull_employees_custom_data(parser_module, integration, custom_object, external_employee_ids) do
    Enum.each(external_employee_ids, fn employee_id ->
      {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
        Authentication.Tempworks.get_or_regenerate_service_token(integration)

      case Clients.Tempworks.get_employee_custom_data(access_token, employee_id) do
        {:ok, %{custom_data: custom_data_set}} ->
          # reject empty values
          custom_data =
            custom_data_set
            |> Enum.reject(&(&1.propertyValue == nil))
            |> maybe_append_employee_id_in_custom_data(employee_id)

          convert_custom_data(
            parser_module,
            integration,
            custom_object,
            custom_data,
            employee_id
          )

        {:error, reason} ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error pulling employee custom data for employee #{employee_id} from TempWorks. Skipping employee custom data. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  @spec pull_contact_details(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_contact_details(parser_module, integration, custom_object, limit, offset) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts =
      Contacts.list_integration_synced_contacts_with_prefixing(integration, @contact_prefix_pattern, limit, offset)

    Enum.each(contacts, fn contact ->
      with {:ok, contact_detail} <-
             Clients.Tempworks.get_contact(access_token, contact.external_contact_id),
           {:ok, %{custom_data: custom_data_set}} <-
             Clients.Tempworks.get_tempwork_contact_custom_data(access_token, contact.external_contact_id),
           filtered_custom_data = Enum.reject(custom_data_set, &(&1.propertyValue == nil)),
           {:ok, %CustomObjectRecord{}} <-
             Sync.Workers.CustomData.Converter.convert_bulk_external_resource_to_custom_object_record(
               parser_module,
               integration,
               custom_object,
               get_resources(contact_detail, filtered_custom_data),
               %{whippy_contact_id: contact.whippy_contact_id, external_resource_id: contact.external_contact_id}
             ) do
        :ok
      else
        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error converting tempwork contact detail for contact #{contact.id} with external_id #{contact.external_contact_id} from TempWorks. Skipping contact. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error pulling tempwork contact details for contact #{contact.id} with external_id #{contact.external_contact_id} from TempWorks. Skipping contact. Error: #{inspect(reason)}
          """)
      end
    end)

    if Enum.count(contacts) < limit do
      update_offset(:contact, integration, 0)
    else
      # lets set the offset when the current chunk has been finished.
      update_offset(:contact, integration, offset)
      pull_contact_details(parser_module, integration, custom_object, limit, offset + limit)
    end
  end

  # Soon to be deprecated
  @spec pull_tempworks_contacts_custom_data(
          atom(),
          Integration.t(),
          Ecto.UUID.generate(),
          CustomObject.t()
        ) :: :ok
  def pull_tempworks_contacts_custom_data(parser_module, integration, contact_custom_object_id, data_custom_object) do
    external_contact_ids =
      Contacts.list_prefix_external_ids_of_custom_object_records(
        integration.id,
        contact_custom_object_id,
        @contact_prefix_pattern
      )

    # |> Enum.map(&String.to_integer/1)

    do_pull_tempworks_contacts_custom_data(
      parser_module,
      integration,
      data_custom_object,
      external_contact_ids
    )
  end

  defp do_pull_tempworks_contacts_custom_data(parser_module, integration, custom_object, external_contact_ids) do
    Enum.each(external_contact_ids, fn contact_id ->
      {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
        Authentication.Tempworks.get_or_regenerate_service_token(integration)

      case Clients.Tempworks.get_tempwork_contact_custom_data(access_token, contact_id) do
        {:ok, %{custom_data: custom_data_set}} ->
          # reject empty values
          custom_data =
            custom_data_set
            |> Enum.reject(&(&1.propertyValue == nil))
            |> maybe_append_employee_id_in_custom_data(contact_id)

          convert_custom_data(
            parser_module,
            integration,
            custom_object,
            custom_data,
            contact_id
          )

        {:error, reason} ->
          Logger.error("""
          [TempWorks] [#{integration.id}] Error pulling tempwork contact custom data for employee #{contact_id} from TempWorks. Skipping contact custom data. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  def lookup_employees_in_tempworks(integration, limit) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts = Contacts.list_integration_contacts_missing_from_external_integration_for_lookup(integration, limit)

    Enum.each(contacts, fn contact ->
      contact.whippy_contact["phone"] && lookup_individual_employee_in_tempworks(integration, access_token, contact)
    end)

    Contacts.update_contacts_as_looked_up(integration, contacts)

    if Enum.count(contacts) < limit do
      :ok
    else
      lookup_employees_in_tempworks(integration, limit)
    end
  end

  defp lookup_individual_employee_in_tempworks(integration, access_token, contact) do
    employee_payload = Clients.Tempworks.Parser.convert_contact_to_employee(contact)

    Logger.info(
      "[TempWorks] [#{integration.id}] Looking up employee with phone #{employee_payload.primaryPhoneNumber} in TempWorks for contact #{contact.name} with ID #{contact.id}"
    )

    case Tempworks.Writer.get_employees_from_external_integration_using_phone(employee_payload, access_token) do
      {:ok, []} ->
        nil

      {:ok, employee_list} ->
        Logger.info(
          "[TempWorks] [#{integration.id}] Found employee universal phone #{employee_payload.primaryPhoneNumber} for contact #{contact.name} with ID #{contact.id}"
        )

        Tempworks.Writer.update_first_map_from_list_to_sync(employee_list, integration, contact)

      {:error, error} ->
        Logger.error(
          "[TempWorks] [#{integration.id}] Error getting employee universal phone #{employee_payload.primaryPhoneNumber} for contact #{contact.name} with ID #{contact.id}: #{inspect(error)}"
        )

        nil
    end
  end

  def monthly_pull_birthdays_from_tempworks(integration, limit) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    contacts = Contacts.list_integration_contacts_missing_birthday(integration, limit)

    updated_contacts =
      Enum.map(contacts, fn contact ->
        birth_date =
          case Clients.Tempworks.get_employee_eeo(access_token, contact.external_contact_id) do
            {:ok, employee_eeo_detail} ->
              employee_eeo_detail.dateOfBirth

            {:error, reason} ->
              Logger.error(
                "[TempWorks] [#{integration.id}] Error getting employee birthday for contact name  #{contact.name} and id #{contact.external_contact_id}: #{inspect(reason)}"
              )

              nil
          end

        Map.from_struct(%{contact | birth_date: birth_date})
      end)

    Contacts.save_external_contacts(integration, updated_contacts)

    if Enum.count(contacts) < limit do
      :ok
    else
      monthly_pull_birthdays_from_tempworks(integration, limit)
    end
  end

  #####################################
  ##    Branches (Whippy Channels)   ##
  #####################################

  @spec pull_branches(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_branches(integration, limit, offset) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_branches(access_token,
           active: true,
           limit: limit,
           offset: offset
         ) do
      # we'll disregard total here just in case it is not equivalent to the length of the returned list
      {:ok, %{total: _total, branches: branches}} when length(branches) < limit ->
        Channels.save_external_channels(integration, branches)

      {:ok, %{total: _total, branches: branches}} ->
        Channels.save_external_channels(integration, branches)

        pull_branches(integration, limit, offset + limit)
    end
  end

  def get_employee_from_tempwork_and_update_to_sync(integration, access_token, contact) do
    employee_payload = Clients.Tempworks.Parser.convert_contact_to_employee(contact)

    case Tempworks.Writer.get_employees_from_external_integration_using_phone(employee_payload, access_token) do
      {:ok, []} ->
        Logger.warning("Error Contact #{contact.phone} not present in tempworks integration #{integration.id}")

      {:ok, employee_list} ->
        Tempworks.Writer.update_first_map_from_list_to_sync(employee_list, integration, contact)

      {:error, error} ->
        Logger.warning(
          "Error getting employee phone for contact #{contact.phone}  integration #{integration.id}: #{inspect(error)}"
        )
    end
  end

  #############################################
  ##   Assignments (Custom Data in Whippy)   ##
  #############################################

  @spec pull_advance_assignments(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_advance_assignments(parser_module, integration, custom_object, limit, offset) do
    external_contact_ids =
      integration
      |> Contacts.list_integration_synced_external_contact_ids()
      |> Enum.map(&String.to_integer/1)

    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    {:ok, raw_columns} = Clients.Tempworks.list_assignment_columns(access_token)

    # Filter columns, which can't be queried.
    columns = process_assignment_column(raw_columns)

    do_pull_advance_assignments(
      parser_module,
      integration,
      columns,
      custom_object,
      external_contact_ids,
      limit,
      offset
    )
  end

  defp do_pull_advance_assignments(
         parser_module,
         integration,
         columns,
         custom_object,
         external_contact_ids,
         limit,
         offset
       ) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    opts = [limit: limit, offset: offset, columns: columns]

    case Clients.Tempworks.list_assignments_advance_details(access_token, opts) do
      {:ok, %{assignments: assignments}} ->
        selected_assignments = Enum.filter(assignments, &(&1["employeeId"] in external_contact_ids))
        # selected_assignments = assignments
        Logger.info("""
        [TempWorks] [#{integration.id}] Found #{Enum.count(selected_assignments)} assignments for employees in the integration.
        """)

        save_advance_assignments(parser_module, selected_assignments, integration, custom_object)

        if Enum.count(assignments) < limit do
          update_offset(:advance_assignment_offset, integration, 0)
        else
          update_offset(:advance_assignment_offset, integration, offset)

          do_pull_advance_assignments(
            parser_module,
            integration,
            columns,
            custom_object,
            external_contact_ids,
            limit,
            offset + limit
          )
        end

      {:error, reason} ->
        Logger.warning(
          "[TempWorks] [#{integration.id}] Error pulling assignments with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # skip batch and move to the next one
        do_pull_advance_assignments(
          parser_module,
          integration,
          columns,
          custom_object,
          external_contact_ids,
          limit,
          offset + limit
        )
    end
  end

  defp save_advance_assignments(parser_module, selected_assignments, integration, custom_object) do
    Enum.each(selected_assignments, fn assignment ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             assignment
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error converting assignment for employee #{assignment.employee_id} from TempWorks. Skipping assignment. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error pulling assignment for employee #{assignment.employee_id} from TempWorks. Skipping assignment. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  @spec pull_assignments(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_assignments(parser_module, integration, custom_object, limit, offset) do
    external_contact_ids =
      integration
      |> Contacts.list_integration_synced_external_contact_ids()
      |> Enum.reject(fn id -> String.starts_with?(id, "contact-") end)
      |> Enum.map(&String.to_integer/1)

    branches_to_sync = fetch_branches_to_sync(integration)

    if branches_to_sync != [] do
      Enum.each(branches_to_sync, fn branch_id ->
        Logger.info("Pulling assignments for branch #{branch_id} integration #{integration.id}")

        do_pull_assignments(
          parser_module,
          integration,
          custom_object,
          external_contact_ids,
          limit,
          0,
          branch_id
        )
      end)
    else
      do_pull_assignments(
        parser_module,
        integration,
        custom_object,
        external_contact_ids,
        limit,
        offset
      )
    end
  end

  defp do_pull_assignments(
         parser_module,
         integration,
         custom_object,
         external_contact_ids,
         limit,
         offset,
         branch_id \\ nil
       ) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    opts = [limit: limit, offset: offset, branch_id: branch_id]

    opts =
      if integration.settings["only_active_assignments"],
        do: Keyword.put(opts, :is_active, true),
        else: opts

    case Clients.Tempworks.list_assignments(access_token, opts) do
      {:ok, %{assignments: assignments}} ->
        selected_assignments = Enum.filter(assignments, &(&1.employeeId in external_contact_ids))

        Logger.info("""
        [TempWorks] [#{integration.id}] Found #{Enum.count(selected_assignments)} maybe branch id #{branch_id} or all  assignments for employees in the integration.
        """)

        save_assignments_and_fetch_custom_data(parser_module, selected_assignments, integration, custom_object)

        if Enum.count(assignments) < limit do
          update_offset(:assignment, integration, 0)
        else
          update_offset(:assignment, integration, offset)

          do_pull_assignments(
            parser_module,
            integration,
            custom_object,
            external_contact_ids,
            limit,
            offset + limit
          )
        end

      {:error, reason} ->
        Logger.warning(
          "[TempWorks] [#{integration.id}] Error pulling assignments with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # skip batch and move to the next one
        do_pull_assignments(
          parser_module,
          integration,
          custom_object,
          external_contact_ids,
          limit,
          offset + limit
        )
    end
  end

  defp save_assignments_and_fetch_custom_data(parser_module, selected_assignments, integration, custom_object) do
    Enum.each(selected_assignments, fn assignment ->
      # Fetch custom data for the assignment
      custom_data = fetch_assignment_custom_data(integration, assignment)

      case Converter.convert_bulk_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             get_resources(assignment, custom_data),
             %{external_resource_id: assignment.assignmentId}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error converting assignment for employee #{assignment.employee_id} from TempWorks. Skipping assignment. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error pulling assignment for employee #{assignment.employee_id} from TempWorks. Skipping assignment. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  defp fetch_assignment_custom_data(integration, assignment) do
    assignment_id = assignment.assignmentId

    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.get_assignment_custom_data(access_token, assignment_id) do
      {:ok, %{custom_data: custom_data_set}} ->
        # reject empty records
        custom_data =
          custom_data_set
          |> Enum.reject(&(&1.propertyValue == nil))
          |> maybe_append_assignment_id_in_custom_data(assignment_id)

        custom_data

      {:error, reason} ->
        Logger.warning("""
        [TempWorks] [#{integration.id}] Error pulling assignment custom data for assignment #{assignment_id} from TempWorks. Skipping assignment custom data. Error: #{inspect(reason)}
        """)

        []
    end
  end

  @spec pull_assignments_custom_data(
          atom(),
          Integration.t(),
          Ecto.UUID.t(),
          CustomObject.t()
        ) :: :ok
  def pull_assignments_custom_data(parser_module, integration, assignment_custom_object_id, data_custom_object) do
    external_assignment_ids =
      integration.id
      |> Contacts.list_external_ids_of_custom_object_records(assignment_custom_object_id)
      |> Enum.map(&String.to_integer/1)

    do_pull_assignments_custom_data(
      parser_module,
      integration,
      data_custom_object,
      external_assignment_ids
    )
  end

  defp do_pull_assignments_custom_data(parser_module, integration, custom_object, external_assignment_ids) do
    Enum.each(external_assignment_ids, fn assignment_id ->
      {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
        Authentication.Tempworks.get_or_regenerate_service_token(integration)

      case Clients.Tempworks.get_assignment_custom_data(access_token, assignment_id) do
        {:ok, %{custom_data: custom_data_set}} ->
          # reject empty records
          custom_data =
            custom_data_set
            |> Enum.reject(&(&1.propertyValue == nil))
            |> maybe_append_assignment_id_in_custom_data(assignment_id)

          convert_custom_data(
            parser_module,
            integration,
            custom_object,
            custom_data,
            assignment_id
          )

        {:error, reason} ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error pulling assignment custom data for assignment #{assignment_id} from TempWorks. Skipping assignment custom data. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  defp convert_custom_data(_parser_module, integration, _custom_object, [], external_resource_id) do
    Logger.info("""
    [TempWorks] [#{integration.id}] No custom data to save for #{external_resource_id}. Skipping.
    """)

    :ok
  end

  defp convert_custom_data(parser_module, integration, custom_object, custom_data, external_resource_id) do
    case Converter.convert_external_resource_to_custom_object_record(
           parser_module,
           integration,
           custom_object,
           custom_data,
           %{external_resource_id: external_resource_id}
         ) do
      {:ok, %CustomObjectRecord{}} ->
        :ok

      {:error, %Ecto.Changeset{}} = changeset ->
        Logger.warning("""
        [TempWorks] [#{integration.id}] Error converting #{custom_object.external_entity_type}. Skipping. Error: #{inspect(changeset)}
        """)

      {:error, reason} ->
        Logger.warning("""
        [TempWorks] [#{integration.id}] Error converting #{custom_object.external_entity_type}. Skipping. Error: #{inspect(reason)}
        """)
    end
  end

  ########################
  ###  Job Orders  ###
  ########################

  @spec pull_job_orders(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_job_orders(parser_module, integration, custom_object, limit, offset) do
    branches_to_sync = fetch_branches_to_sync(integration)

    if branches_to_sync != [] do
      Enum.each(branches_to_sync, fn branch_id ->
        Logger.info("Pulling job orders for branch #{branch_id} integration #{integration.id}")

        do_pull_job_orders(
          parser_module,
          integration,
          custom_object,
          limit,
          0,
          branch_id
        )
      end)
    else
      do_pull_job_orders(
        parser_module,
        integration,
        custom_object,
        limit,
        offset
      )
    end
  end

  def do_pull_job_orders(parser_module, integration, custom_object, limit, offset, branch_id \\ nil) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    opts = [limit: limit, offset: offset, branch_id: branch_id]

    case Clients.Tempworks.list_job_orders(access_token, opts) do
      {:ok, %{job_orders: job_orders}} ->
        Logger.info("""
        [TempWorks] [#{integration.id}] Found #{Enum.count(job_orders)} job_orders in the integration.
        """)

        save_job_orders_and_fetch_custom_data(parser_module, job_orders, integration, custom_object)

        if Enum.count(job_orders) < limit do
          # Reset offset only if we're not processing specific branches
          maybe_update_offset(:job_orders, integration, branch_id)
        else
          # Only update offset when not processing specific branches
          maybe_update_offset(:job_orders, integration, offset, branch_id)

          # Continue pagination with same branch_id
          do_pull_job_orders(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            # Preserve branch_id
            branch_id
          )
        end

      {:error, reason} ->
        Logger.warning(
          "[TempWorks] [#{integration.id}] Error pulling job_orders with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # Continue pagination with same branch_id
        do_pull_job_orders(
          parser_module,
          integration,
          custom_object,
          limit,
          offset + limit,
          # Preserve branch_id
          branch_id
        )
    end
  end

  defp maybe_update_offset(custom_object_type, integration, branch_id) do
    if branch_id == nil do
      update_offset(custom_object_type, integration, 0)
    end
  end

  defp maybe_update_offset(custom_object_type, integration, offset, branch_id) do
    if branch_id == nil do
      update_offset(custom_object_type, integration, offset)
    end
  end

  defp save_job_orders_and_fetch_custom_data(parser_module, job_orders, integration, custom_object) do
    Enum.each(job_orders, fn job_order ->
      # Fetch custom data for the job_order
      custom_data = fetch_job_order_custom_data(integration, job_order)

      case Converter.convert_bulk_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             get_resources(job_order, custom_data),
             %{external_resource_id: job_order.orderId}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error converting job_order #{job_order.order_id} from TempWorks. Skipping job_order. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error pulling job_order #{job_order.order_id} from TempWorks. Skipping job_order. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  defp fetch_job_order_custom_data(integration, job_order) do
    order_id = job_order.orderId

    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.get_job_orders_custom_data(access_token, order_id) do
      {:ok, %{custom_data: custom_data_set}} ->
        # reject empty records
        custom_data =
          custom_data_set
          |> Enum.reject(&(&1.propertyValue == nil))
          |> maybe_append_job_order_id_in_custom_data(order_id)

        custom_data

      {:error, reason} ->
        Logger.warning("""
        [TempWorks] [#{integration.id}] Error pulling job_order custom data for job_order #{order_id} from TempWorks. Skipping job_order custom data. Error: #{inspect(reason)}
        """)

        []
    end
  end

  ########################
  ###  Job Orders End ###
  ########################

  ########################
  ###  Customers Start ###
  ########################

  @spec pull_customers(
          atom(),
          Integration.t(),
          CustomObject.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok

  def pull_customers(parser_module, integration, custom_object, limit, offset) do
    branches_to_sync = fetch_branches_to_sync(integration)

    if branches_to_sync != [] do
      Enum.each(branches_to_sync, fn branch_id ->
        Logger.info("Pulling customers for branch #{branch_id} integration #{integration.id}")

        do_pull_customers(
          parser_module,
          integration,
          custom_object,
          limit,
          0,
          branch_id
        )
      end)
    else
      do_pull_customers(
        parser_module,
        integration,
        custom_object,
        limit,
        offset
      )
    end
  end

  def do_pull_customers(parser_module, integration, custom_object, limit, offset, branch_id \\ nil) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    opts = [limit: limit, offset: offset, branch_id: branch_id]

    case Clients.Tempworks.list_customers(access_token, opts) do
      {:ok, %{customers: customers}} ->
        Logger.info("""
        [TempWorks] [#{integration.id}] Found #{Enum.count(customers)} customers in the integration.
        """)

        save_customers_and_fetch_custom_data(parser_module, customers, integration, custom_object)

        if Enum.count(customers) < limit do
          maybe_update_offset(:customers, integration, branch_id)
        else
          maybe_update_offset(:customers, integration, offset, branch_id)

          do_pull_customers(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit
          )
        end

      {:error, reason} ->
        Logger.warning(
          "[TempWorks] [#{integration.id}] Error pulling customers with limit #{limit} and offset #{offset} from TempWorks. Skipping batch. Error: #{inspect(reason)}"
        )

        # skip batch and move to the next one
        do_pull_customers(
          parser_module,
          integration,
          custom_object,
          limit,
          offset + limit
        )
    end
  end

  defp save_customers_and_fetch_custom_data(parser_module, customers, integration, custom_object) do
    Enum.each(customers, fn customer ->
      # Fetch custom data for the customer
      custom_data = fetch_customer_custom_data(integration, customer)

      case Converter.convert_bulk_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             get_resources(customer, custom_data),
             %{external_resource_id: customer.customerId}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error converting customer #{customer.customer_id} from TempWorks. Skipping customer. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.warning("""
          [TempWorks] [#{integration.id}] Error pulling customer #{customer.customer_id} from TempWorks. Skipping customer. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  defp fetch_customer_custom_data(integration, customer) do
    customer_id = customer.customerId

    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.get_customers_custom_data(access_token, customer_id) do
      {:ok, %{custom_data: custom_data_set}} ->
        # reject empty records
        custom_data =
          custom_data_set
          |> Enum.reject(&(&1.propertyValue == nil))
          |> maybe_append_customer_id_in_custom_data(customer_id)

        custom_data

      {:error, reason} ->
        Logger.warning("""
        [TempWorks] [#{integration.id}] Error pulling customer custom data for customer #{customer_id} from TempWorks. Skipping customer custom data. Error: #{inspect(reason)}
        """)

        []
    end
  end

  ########################
  ###  Customers End ###
  ########################

  ########################
  ###  Custom Objects  ###
  ########################

  @spec get_assignment_custom_data(Integration.t()) ::
          %{custom_data: [Clients.Tempworks.Model.CustomData.t()]} | nil
  def get_assignment_custom_data(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, %{assignments: [%{assignmentId: assignment_id} | _]}} <-
           Clients.Tempworks.list_assignments(access_token),
         {:ok, %{custom_data: custom_data}} <-
           Clients.Tempworks.get_assignment_custom_data(access_token, assignment_id) do
      %{
        custom_data: [
          %Clients.Tempworks.Model.CustomData{
            propertyName: "Assignment ID",
            propertyType: "integer"
          }
          | custom_data
        ]
      }
    else
      error ->
        Logger.warning("[TempWorks] [Integration #{integration.id}]  Error getting assignments: #{inspect(error)}")

        nil
    end
  end

  @spec get_employee_custom_data(Integration.t()) ::
          %{custom_data: [Clients.Tempworks.Model.CustomData.t()]} | nil
  def get_employee_custom_data(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, %{employees: [%{external_contact_id: employee_id} | _]}} <-
           Clients.Tempworks.list_employees(access_token),
         {:ok, %{custom_data: custom_data}} <-
           Clients.Tempworks.get_employee_custom_data(access_token, employee_id) do
      %{
        custom_data: [
          %Clients.Tempworks.Model.CustomData{
            propertyName: "Employee ID",
            propertyType: "integer"
          }
          | custom_data
        ]
      }
    else
      error ->
        Logger.warning(
          "[TempWorks] [Integration #{integration.id}] Error getting employee custom data: #{inspect(error)}"
        )

        nil
    end
  end

  @spec get_contact_custom_data(Integration.t()) ::
          %{custom_data: [Clients.Tempworks.Model.CustomData.t()]} | nil
  def get_contact_custom_data(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, %{contacts: [%{external_contact_id: contact_id} | _]}} <-
           Clients.Tempworks.list_contacts(access_token),
         {:ok, %{custom_data: custom_data}} <-
           Clients.Tempworks.get_tempwork_contact_custom_data(access_token, contact_id) do
      %{
        custom_data: [
          %Clients.Tempworks.Model.CustomData{
            propertyName: "Contact ID",
            propertyType: "integer"
          }
          | custom_data
        ]
      }
    else
      error ->
        Logger.warning("[TempWorks] [Integration #{integration.id}] Error getting contact custom data: #{inspect(error)}")

        nil
    end
  end

  @spec get_jobs_custom_data(Integration.t()) ::
          %{custom_data: [Clients.Tempworks.Model.CustomData.t()]} | nil
  def get_jobs_custom_data(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, %{job_orders: [%{orderId: order_id} | _]}} <-
           Clients.Tempworks.list_job_orders(access_token),
         {:ok, %{custom_data: custom_data}} <-
           Clients.Tempworks.get_job_orders_custom_data(access_token, order_id) do
      %{
        custom_data: [
          %Clients.Tempworks.Model.CustomData{
            propertyName: "JobOrder ID",
            propertyType: "integer"
          }
          | custom_data
        ]
      }
    else
      error ->
        Logger.warning("[TempWorks] [Integration #{integration.id}]  Error getting job orders: #{inspect(error)}")
        nil
    end
  end

  @spec get_customer_custom_data(Integration.t()) ::
          %{custom_data: [Clients.Tempworks.Model.CustomData.t()]} | nil
  def get_customer_custom_data(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    with {:ok, %{customers: [%{customerId: customer_id} | _]}} <-
           Clients.Tempworks.list_customers(access_token),
         {:ok, %{custom_data: custom_data}} <-
           Clients.Tempworks.get_customers_custom_data(access_token, customer_id) do
      %{
        custom_data: [
          %Clients.Tempworks.Model.CustomData{
            propertyName: "Customer ID",
            propertyType: "integer"
          }
          | custom_data
        ]
      }
    else
      error ->
        Logger.error("[TempWorks] [Integration #{integration.id}]  Error getting customers: #{inspect(error)}")

        nil
    end
  end

  ##################
  ##   webhooks   ##
  ##################
  def get_advance_search_columns(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_employee_columns(access_token) do
      {:ok, columns} ->
        %{columns: columns["data"]}

      {:error, error} ->
        Logger.error("[TempWorks] [Integration #{integration.id}] Error getting employee columns: #{inspect(error)}")

        nil
    end
  end

  def get_advance_assignment_columns(integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    case Clients.Tempworks.list_assignment_columns(access_token) do
      {:ok, columns} ->
        %{columns: columns["data"]}

      {:error, error} ->
        Logger.error("[TempWorks] [Integration #{integration.id}] Error getting assignment columns: #{inspect(error)}")

        nil
    end
  end

  defp maybe_append_employee_id_in_custom_data([], _employee_id), do: []

  defp maybe_append_employee_id_in_custom_data(custom_data_set, employee_id) do
    custom_data = %Clients.Tempworks.Model.CustomData{
      propertyValue: employee_id,
      propertyName: "employee_id"
    }

    [custom_data | custom_data_set]
  end

  defp maybe_append_assignment_id_in_custom_data([], _assignment_id), do: []

  defp maybe_append_assignment_id_in_custom_data(custom_data_set, assignment_id) do
    custom_data = %Clients.Tempworks.Model.CustomData{
      propertyValue: assignment_id,
      propertyName: "assignment_id"
    }

    [custom_data | custom_data_set]
  end

  defp maybe_append_job_order_id_in_custom_data([], _job_order_id), do: []

  defp maybe_append_job_order_id_in_custom_data(custom_data_set, job_order_id) do
    custom_data = %Clients.Tempworks.Model.CustomData{
      propertyValue: job_order_id,
      propertyName: "job_order_id"
    }

    [custom_data | custom_data_set]
  end

  defp maybe_append_customer_id_in_custom_data([], _customer_id), do: []

  defp maybe_append_customer_id_in_custom_data(custom_data_set, customer_id) do
    custom_data = %Clients.Tempworks.Model.CustomData{
      propertyValue: customer_id,
      propertyName: "customer_id"
    }

    [custom_data | custom_data_set]
  end

  def update_offset(:employee, integration, offset) do
    integration = Integrations.get_integration!(integration.id)

    settings = Map.put(integration.settings, "employee_details_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:advance_employee_offset, integration, offset) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "advance_employee_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:advance_assignment_offset, integration, offset) do
    integration = Integrations.get_integration!(integration.id)

    settings = Map.put(integration.settings, "advance_assignment_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:assignment, integration, offset) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "assignment_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:contact, integration, offset) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "contact_details_offset", offset)
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:job_orders, integration, offset) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "job_orders_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  def update_offset(:customers, integration, offset) do
    integration = Integrations.get_integration!(integration.id)
    settings = Map.put(integration.settings, "customers_offset", offset)
    # TODO: Use update_integration_settings
    Integrations.update_integration(integration, %{settings: settings})
  end

  defp fetch_branches_to_sync(%Integration{settings: %{"branches_to_sync" => branches_to_sync}}), do: branches_to_sync
  defp fetch_branches_to_sync(_), do: []
end
