defmodule Sync.Clients.Tempworks.Parser do
  @moduledoc """
  A module used for defining methods to convert from the data received from
  Tempworks into their formatted structs. For example, it will convert a string based
  map into a Address struct.
  """
  @behaviour Sync.Behaviours.Clients.CustomDataParser

  alias Sync.Clients.Tempworks.Model.Address
  alias Sync.Clients.Tempworks.Model.Branch
  alias Sync.Clients.Tempworks.Model.CustomData
  alias Sync.Clients.Tempworks.Model.Customers
  alias Sync.Clients.Tempworks.Model.Employee
  alias Sync.Clients.Tempworks.Model.EmployeeAssignment
  alias Sync.Clients.Tempworks.Model.EmployeeDetail
  alias Sync.Clients.Tempworks.Model.EmployeeEeoDetail
  alias Sync.Clients.Tempworks.Model.EmployeeStatus
  alias Sync.Clients.Tempworks.Model.JobOrdersWebhook
  alias Sync.Clients.Tempworks.Model.MessageAction
  alias Sync.Clients.Tempworks.Model.TempworkContact
  alias Sync.Clients.Tempworks.Model.TempworkContactDetail
  alias Sync.Clients.Tempworks.Model.TempworksJobOrders
  alias Sync.Clients.Tempworks.Model.UniversalEmail
  alias Sync.Clients.Tempworks.Model.UniversalPhone
  alias Sync.Clients.Tempworks.Model.WebhookCustomData
  alias Sync.Clients.Tempworks.Model.WebhookCustomers
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Utils.Format.StringUtil
  alias Sync.Utils.Parsers.CustomDataUtil

  @default_birthday_year 2000

  def parse_employees(%{"totalCount" => total_count, "data" => employees}) do
    employees
    |> Enum.map(&parse_employee/1)
    |> then(fn employees -> {:ok, %{employees: employees, total: total_count}} end)
  end

  def parse_employee(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    Employee
    |> struct(atom_based_keys)
    |> convert_employee_to_contact()
  end

  def parse_contacts(%{"totalCount" => total_count, "data" => contacts}) do
    contacts
    |> Enum.map(&parse_contact/1)
    |> then(fn contacts -> {:ok, %{contacts: contacts, total: total_count}} end)
  end

  def parse_contact(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    TempworkContact
    |> struct(atom_based_keys)
    |> convert_tempwork_contact_to_sync_contact()
  end

  def parse_contact_contact_methods(%{"totalCount" => _total_count, "data" => contact_methods}) do
    {:ok, contact_methods}
  end

  def parse_employee_detail(object) do
    atom_based_keys = Enum.map(object, &maybe_structure_address/1)
    struct(EmployeeDetail, atom_based_keys)
  end

  def parse_contact_detail(object) do
    atom_based_keys = Enum.map(object, &maybe_structure_address/1)
    struct(TempworkContactDetail, atom_based_keys)
  end

  def parse_employee_eeo_detail(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(EmployeeEeoDetail, atom_based_keys)
  end

  def parse_customers(%{"totalCount" => total_count, "data" => customers}) do
    customers
    |> Enum.map(&parse_customer/1)
    |> then(fn customers -> {:ok, %{customers: customers, total: total_count}} end)
  end

  def parse_customer(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(Customers, atom_based_keys)
  end

  def parse_custom_data_set(%{"totalCount" => total_count, "data" => custom_data_list}) do
    custom_data_list
    |> Enum.map(&parse_custom_data/1)
    |> then(fn custom_data -> {:ok, %{custom_data: custom_data, total: total_count}} end)
  end

  def parse_custom_data(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(CustomData, atom_based_keys)
  end

  def parse_webhook_custom_data(property_values) do
    Enum.map(property_values, fn property_value ->
      atom_based_keys =
        Enum.map(property_value, fn {k, v} ->
          {String.to_atom(k), v}
        end)

      struct(WebhookCustomData, atom_based_keys)
    end)
  end

  def parse_todays_employees(%{"data" => data, "totalCount" => total_count}) do
    # extract the employee ids
    employee_ids = Enum.map(data, & &1["Id"]["value"])

    {:ok, %{employee_ids: employee_ids, total: total_count}}
  end

  def parse_employee_status(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(EmployeeStatus, atom_based_keys)
  end

  def parse_advance_search(%{"columns" => columns, "data" => advance_search_data, "totalCount" => total_count}) do
    # extract the columns
    column_map = parse_columns(columns)

    # Transform the data to use displayName as keys
    employees =
      advance_search_data
      |> Enum.map(&transform_row(&1, column_map))
      |> Enum.map(&StringUtil.to_camel_case_keys/1)
      |> Enum.map(&convert_advance_employee_to_contact/1)

    {:ok, %{employees: employees, total: total_count}}
  end

  def parse_advance_assignment_search(%{"columns" => columns, "data" => advance_search_data}) do
    column_map = parse_columns(columns)

    assignments =
      advance_search_data
      |> Enum.map(&transform_row(&1, column_map))
      |> Enum.map(&StringUtil.to_camel_case_keys/1)
      |> Enum.map(fn assignment ->
        Map.update!(assignment, "active", fn value -> value == 1 end)
      end)

    {:ok, %{assignments: assignments}}
  end

  defp parse_columns(columns) do
    Enum.reduce(columns, %{}, fn %{"columnId" => id, "displayName" => name}, acc ->
      Map.put(acc, id, name)
    end)
  end

  def parse_subscriptions(%{"subscriptions" => subscriptions}) do
    {:ok, Enum.filter(subscriptions, & &1["isActive"])}
  end

  def parse_new_subscriptions(%{"subscriptionId" => subscriptionId}) do
    {:ok, subscriptionId}
  end

  defp convert_advance_employee_to_contact(
         %{
           "firstName" => first_name,
           "lastName" => last_name,
           "phone" => phone,
           "cellPhone" => cell_phone,
           "email" => email,
           "id" => external_contact_id
         } = employee
       ) do
    # NOTE: date_of_birth -> Tempworks doesn't returns at the moment.
    %{
      external_contact_id: "#{external_contact_id}",
      phone: phone || cell_phone,
      name: "#{first_name} #{last_name}",
      email: email,
      address: parse_address(employee),
      external_contact: employee,
      external_organization_entity_type: "employee"
    }
  end

  defp parse_webhook_birthday(birthday) when is_binary(birthday) do
    [b_month, b_day] = String.split(birthday, "/")

    @default_birthday_year
    |> Date.new!(String.to_integer(b_month), String.to_integer(b_day))
    |> Date.to_iso8601()
  end

  defp parse_webhook_birthday(_), do: nil

  defp parse_date(birthday) when is_binary(birthday) do
    case Date.from_iso8601(birthday) do
      {:ok, date} -> %{day: date.day, month: date.month, year: date.year}
      _ -> %{}
    end
  end

  defp parse_date(_), do: %{}

  defp parse_address(%{
         "city" => city,
         "street1" => street1,
         "street2" => street2,
         "state" => state,
         "zipCode" => postal_code
       }) do
    %{
      address_line_one: street1,
      address_line_two: street2,
      post_code: postal_code,
      state: state,
      city: city
    }
  end

  defp transform_row(row, column_map) do
    Enum.reduce(row, %{}, fn
      {"Id", %{"value" => id}}, acc ->
        Map.put(acc, "Id", id)

      {column_id, %{"value" => value}}, acc when is_map(column_map) ->
        display_name = Map.get(column_map, column_id, column_id)
        Map.put(acc, display_name, value)

      _, acc ->
        acc
    end)
  end

  def parse_employee_assignments(%{"totalCount" => total_count, "data" => assignments}) do
    assignments
    |> Enum.map(&parse_employee_assignment/1)
    |> then(fn assignments -> {:ok, %{assignments: assignments, total: total_count}} end)
  end

  def parse_employee_assignment(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(EmployeeAssignment, atom_based_keys)
  end

  def parse_job_orders(%{"totalCount" => total_count, "data" => job_orders}) do
    job_orders
    |> Enum.map(&parse_job_order/1)
    |> then(fn job_orders -> {:ok, %{job_orders: job_orders, total: total_count}} end)
  end

  def parse_job_order(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(TempworksJobOrders, atom_based_keys)
  end

  def parse_webhook_job_order(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(JobOrdersWebhook, atom_based_keys)
  end

  def parse_webhook_customer(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(WebhookCustomers, atom_based_keys)
  end

  def parse_message_actions(%{"totalCount" => total_count, "data" => message_actions}) do
    message_actions
    |> Enum.map(&parse_message_action/1)
    |> then(fn message_actions ->
      {:ok, %{message_actions: message_actions, total: total_count}}
    end)
  end

  def parse_message_action(object) do
    atom_based_keys = Enum.map(object, &maybe_structure_address/1)

    MessageAction
    |> struct(atom_based_keys)
    |> convert_message_action_to_activity_type()
  end

  defp maybe_structure_address({"address", nil}) do
    {:address, nil}
  end

  defp maybe_structure_address({"address", value}) do
    atom_based_address =
      Enum.map(value, fn {key, value} ->
        {String.to_atom(key), value}
      end)

    address_struct = struct(Address, atom_based_address)
    {:address, address_struct}
  end

  defp maybe_structure_address({"worksiteAddress", nil}) do
    {:worksiteAddress, nil}
  end

  defp maybe_structure_address({"worksiteAddress", value}) do
    atom_based_address =
      Enum.map(value, fn {key, value} ->
        {String.to_atom(key), value}
      end)

    address_struct = struct(Address, atom_based_address)
    {:worksiteAddress, address_struct}
  end

  defp maybe_structure_address({key, value}) do
    {String.to_atom(key), value}
  end

  # Parse the list branches response object into a map with parsed branches and the total count.
  def parse_branches(%{"totalCount" => total_count, "data" => branches}) do
    branches
    |> Enum.map(&parse_branch/1)
    |> then(fn branches -> {:ok, %{branches: branches, total: total_count}} end)
  end

  # Parse the branches object into a struct,
  # if the key is an address, we want to make that into a struct as well.
  def parse_branch(branch_object) do
    atom_based_keys = Enum.map(branch_object, &maybe_structure_address/1)

    Branch
    |> struct(atom_based_keys)
    |> convert_branch_to_channel()
  end

  def parse_universal_phone_list(%{"employees" => results, "customers" => _customers, "contacts" => _contacts}) do
    results
    |> Map.get("results")
    |> Map.get("result")
    |> Enum.map(&parse_universal_phone/1)
  end

  def parse_universal_phone(employees_list) do
    atom_based_keys =
      Enum.map(employees_list, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(UniversalPhone, atom_based_keys)
  end

  def parse_universal_email_list(%{"employees" => results, "customers" => _customers, "contacts" => _contacts}) do
    results
    |> Map.get("results")
    |> Map.get("result")
    |> Enum.map(&parse_universal_email/1)
  end

  def parse_universal_email(employees_list) do
    atom_based_keys =
      Enum.map(employees_list, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    struct(UniversalEmail, atom_based_keys)
  end

  def convert_contact_to_employee(%Contact{whippy_contact: %{"name" => name} = contact})
      when is_nil(name) or name == "" do
    %{
      firstName: nil,
      lastName: nil,
      primaryPhoneNumber: contact["phone"],
      primaryEmailAddress: contact["email"],
      primaryPhoneNumberCountryCallingCode: 1,
      countryCode: 840
    }
  end

  def convert_contact_to_employee(%Contact{whippy_contact: contact}) do
    [first_name, last_name] = StringUtil.parse_contact_name(contact["name"])

    %{
      firstName: first_name,
      lastName: last_name,
      primaryPhoneNumber: contact["phone"],
      primaryEmailAddress: contact["email"],
      primaryPhoneNumberCountryCallingCode: 1,
      countryCode: 840
    }
  end

  def convert_employee_to_whippy_contact(%Contact{} = contact) do
    %{
      name: "#{contact.name}",
      phone: contact.phone,
      email: contact.email,
      external_id: contact.external_contact_id,
      default_channel_id: contact.whippy_channel_id,
      integration_id: contact.integration_id,
      birth_date: parse_date(contact.birth_date),
      address: parse_contact_address(contact.address)
    }
  end

  defp convert_employee_to_contact(
         %Employee{
           phoneNumber: phone,
           firstName: first_name,
           lastName: last_name,
           cellPhoneNumber: cell_phone,
           emailAddress: email,
           employeeId: external_contact_id
         } = employee
       ) do
    %{
      external_contact_id: "#{external_contact_id}",
      phone: phone || cell_phone,
      name: "#{first_name} #{last_name}",
      email: email,
      external_contact: parse_external_contact(employee),
      external_organization_entity_type: "employee"
    }
  end

  defp parse_external_contact(employee) do
    employee
    |> Map.put("id", employee.employeeId)
    |> Map.put("zipCode", employee.postalCode)
    |> Map.put("phone", employee.phoneNumber)
    |> Map.put("cellPhone", employee.cellPhoneNumber)
  end

  def convert_employee_detail_to_contact(
        %EmployeeDetail{
          firstName: first_name,
          lastName: last_name,
          primaryPhoneNumber: phone,
          primaryEmailAddress: email,
          employeeId: external_contact_id,
          address: address,
          birthday: birthday
        } = employee,
        integration
      ) do
    external_contact = parse_external_contact_detail(employee)

    %{
      external_contact_id: "#{external_contact_id}",
      phone: phone,
      name: "#{first_name} #{last_name}",
      email: email,
      external_contact: external_contact,
      address: address,
      external_organization_entity_type: "employee",
      integration_id: integration.id,
      birth_date: parse_webhook_birthday(birthday),
      external_organization_id: integration.external_organization_id,
      external_contact_hash: Contacts.calculate_hash(external_contact)
    }
  end

  defp parse_external_contact_detail(employee) do
    employee
    |> Map.put("id", employee.employeeId)
    |> Map.put("zipCode", employee.address.postalCode)
    |> Map.put("phone", employee.primaryPhoneNumber)
  end

  def tempwork_contact_details_to_contact(tempworks_contact, payload, integration) do
    external_contact = parse_external_tempwork_contact_detail(tempworks_contact.external_contact, payload)

    %{
      external_contact_id: tempworks_contact.external_contact_id,
      phone: tempworks_contact.phone,
      name: tempworks_contact.name,
      email: tempworks_contact.email,
      contact_id: tempworks_contact.contact_id,
      external_contact: external_contact,
      address: payload["address"],
      external_organization_entity_type: "contact",
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id,
      external_contact_hash: Contacts.calculate_hash(external_contact)
    }
  end

  defp parse_external_tempwork_contact_detail(tempworks_contact, payload) do
    postal_code = get_in(payload, ["payload", "address", "postalCode"])

    tempworks_contact
    |> Map.put("id", tempworks_contact.contactId)
    |> Map.put("zipCode", postal_code)
    |> Map.put("phone", tempworks_contact.officePhone)
  end

  def convert_tempwork_contact_to_sync_contact(
        %TempworkContact{
          officePhone: phone,
          firstName: first_name,
          lastName: last_name,
          emailAddress: email,
          contactId: external_contact_id
        } = contact
      ) do
    %{
      external_contact_id: "contact-#{external_contact_id}",
      contact_id: external_contact_id,
      phone: phone,
      name: "#{first_name} #{last_name}",
      email: email,
      external_contact: parse_external_tempwork_contact(contact),
      external_organization_entity_type: "contact"
    }
  end

  defp parse_external_tempwork_contact(contact) do
    contact
    |> Map.put("id", contact.contactId)
    |> Map.put("phone", contact.officePhone)
  end

  def parse_webhooks_employee(
        external_contact_id,
        integration,
        %{
          "firstName" => first_name,
          "lastName" => last_name,
          "primaryPhoneNumber" => phone,
          "primaryEmailAddress" => email,
          "employeeId" => external_contact_id
        } = employee
      ) do
    %{
      external_contact_id: "#{external_contact_id}",
      phone: phone,
      name: "#{first_name} #{last_name}",
      email: email,
      external_contact: parse_external_webhook_contact(employee),
      external_organization_entity_type: "employee",
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id
    }
  end

  defp parse_external_webhook_contact(employee) do
    employee
    |> Map.put("id", employee["employeeId"])
    |> Map.put("zipCode", employee["postalCode"])
    |> Map.put("phone", employee["primaryPhoneNumber"])
  end

  def parse_contact_address(nil), do: nil

  def parse_contact_address(address) do
    %{
      address_line_one: Map.get(address, "street1"),
      address_line_two: Map.get(address, "street2"),
      city: Map.get(address, "municipality"),
      post_code: Map.get(address, "postalCode"),
      state: Map.get(address, "region"),
      country_code: Map.get(address, "countryCode"),
      country: Map.get(address, "country"),
      attention_to: Map.get(address, "attentionTo"),
      location: Map.get(address, "location")
    }
  end

  def parse_webhook_address(%{
        "municipality" => municipality,
        "region" => state,
        "postalCode" => postal_code,
        "countryCode" => country_code,
        "country" => country,
        "attentionTo" => attention_to,
        "location" => location,
        "street1" => street1,
        "street2" => street2
      }) do
    %{
      address_line_one: street1,
      address_line_two: street2,
      municipality: municipality,
      post_code: postal_code,
      state: state,
      country_code: country_code,
      country: country,
      attention_to: attention_to,
      location: location
    }
  end

  defp convert_branch_to_channel(%Branch{branchId: external_channel_id} = branch) do
    %{
      external_channel_id: "#{external_channel_id}",
      external_channel: branch
    }
  end

  defp convert_message_action_to_activity_type(%MessageAction{actionId: action_id, action: name}) do
    %{
      name: name,
      activity_type_id: action_id
    }
  end

  ####################
  ## CUSTOM OBJECTS ##
  ####################

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %EmployeeDetail{}, custom_object, _extra_params) do
    Enum.map(EmployeeDetail.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %EmployeeStatus{}, custom_object, _extra_params) do
    Enum.map(EmployeeStatus.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %Employee{}, custom_object, _extra_params) do
    Enum.map(Employee.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %EmployeeAssignment{}, custom_object, _extra_params) do
    Enum.map(EmployeeAssignment.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %TempworkContactDetail{}, custom_object, _extra_params) do
    Enum.map(TempworkContactDetail.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %TempworkContact{}, custom_object, _extra_params) do
    Enum.map(TempworkContact.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %TempworksJobOrders{}, custom_object, _extra_params) do
    Enum.map(TempworksJobOrders.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(integration, %Customers{}, custom_object, _extra_params) do
    Enum.map(Customers.to_list_of_custom_properties(), fn custom_property ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: custom_property
      }
    end)
  end

  def convert_external_resource_to_custom_properties(
        integration,
        %{custom_data: custom_data_set},
        custom_object,
        _extra_params
      ) do
    Enum.map(custom_data_set, fn custom_data ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: %{
          label: custom_data.propertyName,
          key: StringUtil.to_snake_case(custom_data.propertyName),
          type:
            property_type_to_whippy_type(
              custom_data.propertyType,
              custom_data.allowMultipleValues
            )
        }
      }
    end)
  end

  # Advanced search employees.
  def convert_external_resource_to_custom_properties(integration, %{columns: columns}, custom_object, _extra_params) do
    Enum.map(columns, fn column ->
      %{
        integration_id: integration.id,
        custom_object_id: custom_object.id,
        external_organization_id: integration.external_organization_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        external_custom_property: %{
          label: column["columnDisplayName"],
          key: StringUtil.to_snake_case(column["columnDisplayName"]),
          type:
            property_type_to_whippy_type(
              column["returnedColumnType"] || column["columnType"],
              column["isCustomDataJsonArray"]
            )
        }
      }
    end)
  end

  defp property_type_to_whippy_type(property_type, allowed_multiple_values?) do
    tempworks_to_whippy_types = %{
      "date" => "date",
      "datetime" => "date",
      "integer" => "number",
      "decimal" => "float",
      "float" => "float",
      "double" => "float",
      "boolean" => "boolean",
      "money" => "text",
      "string" => if(allowed_multiple_values?, do: "list", else: "text"),
      "guid" => "text",
      "time" => "text"
    }

    Map.get(tempworks_to_whippy_types, property_type, "text")
  end

  ###########################
  ## CUSTOM OBJECT RECORDS ##
  ###########################

  def convert_resource_to_custom_object_record(
        integration,
        %Contact{external_contact: %{"id" => _employee_id} = employee} = contact,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, employee)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, employee)
    )
    |> Map.put(:external_custom_object_record_id, contact.external_contact_id)
  end

  # Convert basic employee response to advance one.
  def convert_resource_to_custom_object_record(
        integration,
        %Contact{external_contact: %{"employeeId" => _employee_id} = employee} = contact,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    employee = convert_basic_to_advance_response(employee)

    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, employee)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, employee)
    )
    |> Map.put(:external_custom_object_record_id, contact.external_contact_id)
  end

  def convert_resource_to_custom_object_record(
        integration,
        %EmployeeDetail{} = employee_detail,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{whippy_contact_id: whippy_contact_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, employee_detail)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, employee_detail)
    )
    |> Map.put(:whippy_associated_resource_type, "contact")
    |> Map.put(:whippy_associated_resource_id, whippy_contact_id)
    |> Map.put(:external_custom_object_record_id, "#{employee_detail.employeeId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %EmployeeStatus{} = employee_status,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{whippy_contact_id: whippy_contact_id, external_resource_id: external_resource_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, employee_status)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, employee_status)
    )
    |> Map.put(:whippy_associated_resource_type, "contact")
    |> Map.put(:whippy_associated_resource_id, whippy_contact_id)
    |> Map.put(:external_custom_object_record_id, "#{external_resource_id}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %EmployeeAssignment{} = assignment,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, assignment)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, assignment)
    )
    |> Map.put(:external_custom_object_record_id, "#{assignment.assignmentId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %TempworksJobOrders{} = job_order,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, job_order)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, job_order)
    )
    |> Map.put(:external_custom_object_record_id, "#{job_order.orderId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %JobOrdersWebhook{} = job_order,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, job_order)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, job_order)
    )
    |> Map.put(:external_custom_object_record_id, "#{job_order.jobOrderId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %Customers{} = customer,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, customer)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, customer)
    )
    |> Map.put(:external_custom_object_record_id, "#{customer.customerId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %WebhookCustomers{} = customer,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, customer)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, customer)
    )
    |> Map.put(:external_custom_object_record_id, "#{customer.customerId}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        %TempworkContactDetail{} = contact_detail,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{whippy_contact_id: whippy_contact_id, external_resource_id: external_resource_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, contact_detail)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, contact_detail)
    )
    |> Map.put(:whippy_associated_resource_type, "contact")
    |> Map.put(:whippy_associated_resource_id, whippy_contact_id)
    |> Map.put(:external_custom_object_record_id, external_resource_id)
  end

  def convert_resource_to_custom_object_record(
        integration,
        %TempworkContact{} = contact_detail,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{whippy_contact_id: whippy_contact_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, contact_detail)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, contact_detail)
    )
    |> Map.put(:whippy_associated_resource_type, "contact")
    |> Map.put(:whippy_associated_resource_id, whippy_contact_id)
    |> Map.put(:external_custom_object_record_id, "#{contact_detail.contactId}")
  end

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_resource_to_custom_object_record(
        integration,
        [%CustomData{} | _] = custom_data,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{external_resource_id: external_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, %{custom_data: custom_data})
    |> Map.put(
      :custom_property_values,
      map_custom_property_values(custom_properties, %{custom_data: custom_data})
    )
    |> Map.put(:external_custom_object_record_id, "#{external_id}")
  end

  def convert_resource_to_custom_object_record(
        integration,
        [%WebhookCustomData{} | _] = custom_data,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        %{external_resource_id: external_id}
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, %{custom_data: custom_data})
    |> Map.put(
      :custom_property_values,
      map_custom_property_values(custom_properties, %{custom_data: custom_data})
    )
    |> Map.put(:external_custom_object_record_id, "#{external_id}")
  end

  # def convert_resource_to_custom_object_record(
  #       integration,
  #       %{} = advance_assignment,
  #       %CustomObject{custom_properties: custom_properties} = custom_object,
  #       _extra_params
  #     ) do
  #   integration
  #   |> CustomDataUtil.base_custom_data_properties(custom_object, advance_assignment)
  #   |> Map.put(
  #     :custom_property_values,
  #     CustomDataUtil.map_custom_property_values(custom_properties, advance_assignment)
  #   )
  #   |> Map.put(:external_custom_object_record_id, "#{advance_assignment["id"]}")
  # end

  defp map_custom_property_values(sync_custom_properties, %{custom_data: external_custom_data_set}) do
    for_result =
      for sync_custom_property <- sync_custom_properties,
          external_custom_data <- external_custom_data_set do
        if sync_custom_property.whippy_custom_property["key"] ==
             StringUtil.to_snake_case(external_custom_data.propertyName) do
          convert_resource_value_to_custom_property_value(
            external_custom_data,
            sync_custom_property
          )
        end
      end

    Enum.reject(for_result, &is_nil/1)
  end

  defp map_custom_property_values(sync_custom_properties, external_resource) do
    Enum.map(
      sync_custom_properties,
      &convert_resource_value_to_custom_property_value(external_resource, &1)
    )
  end

  defp convert_resource_value_to_custom_property_value(%CustomData{} = custom_data_resource, custom_property) do
    %{
      custom_property_id: custom_property.id,
      integration_id: custom_property.integration_id,
      external_custom_property_id: custom_data_resource.propertyDefinitionId,
      external_custom_property_value_id: custom_data_resource.propertyValueId,
      whippy_custom_property_id: custom_property.whippy_custom_property_id,
      external_custom_property_value: custom_data_resource.propertyValue
    }
  end

  defp convert_resource_value_to_custom_property_value(%WebhookCustomData{} = custom_data_resource, custom_property) do
    %{
      custom_property_id: custom_property.id,
      integration_id: custom_property.integration_id,
      external_custom_property_id: custom_data_resource.propertyDefinitionId,
      whippy_custom_property_id: custom_property.whippy_custom_property_id,
      external_custom_property_value: custom_data_resource.propertyValue
    }
  end

  defp convert_resource_value_to_custom_property_value(resource, custom_property) do
    resource = to_string_keys(resource)

    # employee_id -> employeeId
    [head | tail] = String.split(custom_property.whippy_custom_property["key"], "_")
    resource_key = head <> Enum.join(Enum.map(tail, &String.capitalize/1))

    %{
      custom_property_id: custom_property.id,
      integration_id: custom_property.integration_id,
      whippy_custom_property_id: custom_property.whippy_custom_property_id,
      external_custom_property_value: resource[resource_key]
    }
  end

  defp to_string_keys(map) when is_struct(map) do
    map
    |> Map.from_struct()
    |> to_string_keys()
  end

  defp to_string_keys(map) when is_map(map),
    do: Enum.reduce(map, %{}, fn {k, v}, acc -> Map.put(acc, to_string(k), v) end)

  defp to_string_keys(map), do: map

  defp convert_basic_to_advance_response(employee) do
    employee
    |> Map.put("id", employee["employeeId"])
    |> Map.put("zipCode", employee["postalCode"])
    |> Map.put("phone", employee["phoneNumber"])
    |> Map.put("cellPhone", employee["cellPhoneNumber"])
  end
end
