defmodule Sync.Clients.Avionte.Parser do
  @moduledoc """
  A module used for defining methods to convert from the data received from
  Avionte into their formatted structs. For example, it will convert a string based
  map into a Talent struct.
  """
  @behaviour Sync.Behaviours.Clients.CustomDataParser

  alias Sync.Clients.Avionte.Model.AvionteContact
  alias Sync.Clients.Avionte.Model.Branch
  alias Sync.Clients.Avionte.Model.Company
  alias Sync.Clients.Avionte.Model.ContactActivity
  alias Sync.Clients.Avionte.Model.ContactActivityType
  alias Sync.Clients.Avionte.Model.Jobs
  alias Sync.Clients.Avionte.Model.Placement
  alias Sync.Clients.Avionte.Model.Talent
  alias Sync.Clients.Avionte.Model.TalentActivity
  alias Sync.Clients.Avionte.Model.TalentActivityType
  alias Sync.Clients.Avionte.Model.TalentRequirement
  alias Sync.Clients.Avionte.Model.User
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Utils.Format.StringUtil
  alias Sync.Utils.Parsers.CustomDataUtil

  require Logger

  @doc """
  Parses a map body into a struct based on the type.
  In case an unknown type is passed, it will return the body as is.

  ## Arguments
    - `body` - The map body to parse.
    - `type` - The type of the body.

  ## Returns
    - `{:ok, term()}` - A tuple with the parsed struct or a list of structs.
  """
  @type models_to_parse ::
          :talent_ids
          | :talent
          | :talents
          | :talent_activity
          | :talent_activity_types
          | :user
          | :users
          | :branch
          | :branches
          | :contact
          | :contacts
          | :contact_ids
          | :company
          | :companies
          | :company_ids
          | :job
          | :jobs
          | :job_ids
          | :placement
          | :placements
          | :placement_ids
  @spec parse(map(), models_to_parse) :: {:ok, map()} | {:ok, [map()]} | no_return()
  def parse(body, type) do
    {:ok, parse!(body, type)}
  end

  @spec parse!(map(), models_to_parse) :: map() | [map()] | no_return()
  defp parse!(body, :talent), do: body |> Talent.to_struct!() |> convert_talent_to_contact()
  defp parse!(body, :talents), do: Enum.map(body, &parse!(&1, :talent))

  defp parse!(body, :talent_activity), do: TalentActivity.to_struct!(body)
  defp parse!(body, :talent_requirement), do: TalentRequirement.to_struct!(body)

  defp parse!(body, :talent_activity_type),
    do: body |> TalentActivityType.to_struct!() |> convert_avionte_activity_type_to_activity_type()

  defp parse!(body, :talent_activity_types), do: Enum.map(body, &parse!(&1, :talent_activity_type))

  defp parse!(body, :user), do: body |> User.to_struct!() |> convert_avionte_user_to_user()
  defp parse!(body, :users), do: Enum.map(body, &parse!(&1, :user))

  defp parse!(body, :branch), do: body |> Branch.to_struct!() |> convert_avionte_branch_to_channel()
  defp parse!(body, :branches), do: Enum.map(body, &parse!(&1, :branch))

  defp parse!(body, :contact), do: body |> AvionteContact.to_struct!() |> convert_avionte_contact_to_sync_contact()
  defp parse!(body, :contacts), do: Enum.map(body, &parse!(&1, :contact))

  defp parse!(body, :contact_activity), do: ContactActivity.to_struct!(body)

  defp parse!(body, :contact_activity_type),
    do: body |> ContactActivityType.to_struct!() |> convert_avionte_contact_activity_type_to_activity_type()

  defp parse!(body, :contact_activity_types), do: Enum.map(body, &parse!(&1, :contact_activity_type))

  defp parse!(body, :company), do: Company.to_struct!(body)

  defp parse!(body, :companies) do
    body
    |> Enum.reduce([], fn item, acc ->
      try do
        [parse!(item, :company) | acc]
      rescue
        error ->
          Logger.warning("[Avionte] Failed to parse company #{item["id"]}: #{inspect(error)}")
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp parse!(body, :placement), do: Placement.to_struct!(body)

  defp parse!(body, :placements) do
    body
    |> Enum.reduce([], fn item, acc ->
      try do
        [parse!(item, :placement) | acc]
      rescue
        error ->
          Logger.warning("[Avionte] Failed to parse placement #{item["id"]}: #{inspect(error)}")
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp parse!(body, :job), do: Jobs.to_struct!(body)

  defp parse!(body, :jobs) do
    body
    |> Enum.reduce([], fn item, acc ->
      try do
        [parse!(item, :job) | acc]
      rescue
        error ->
          Logger.warning("[Avionte] Failed to parse job #{item["id"]}: #{inspect(error)}")
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp parse!(body, _), do: body

  defp convert_talent_to_contact(
         %Talent{
           id: external_contact_id,
           mobilePhone: phone,
           firstName: first_name,
           lastName: last_name,
           emailAddress: email,
           birthday: birth_date,
           frontOfficeId: channel_id
         } = talent
       ) do
    address = talent.addresses |> Enum.map(fn map -> Map.from_struct(map) end) |> List.first()

    %{
      phone: phone,
      name: "#{first_name} #{last_name}",
      email: StringUtil.downcase_or_nilify(email),
      birth_date: if(birth_date, do: to_string(birth_date)),
      external_contact_id: "#{external_contact_id}",
      address: address,
      external_contact: talent,
      external_channel_id: "#{channel_id}",
      archived: talent.isArchived
    }
  end

  defp convert_avionte_contact_to_sync_contact(
         %AvionteContact{
           id: external_contact_id,
           workPhone: phone,
           cellPhone: cell_phone,
           firstName: first_name,
           lastName: last_name,
           emailAddress: email,
           emailAddress2: email_2,
           address1: address_1,
           address2: address_2,
           city: city,
           state: state,
           postalCode: postal_code,
           country: country
         } = contact
       ) do
    %{
      phone: phone || cell_phone,
      name: "#{first_name} #{last_name}",
      email: StringUtil.downcase_or_nilify(email) || StringUtil.downcase_or_nilify(email_2),
      external_contact_id: "contact-#{external_contact_id}",
      address: %{
        address_line_one: address_1,
        address_line_two: address_2,
        post_code: postal_code,
        country: country,
        state: state,
        city: city
      },
      external_contact: contact,
      archived: contact.isArchived
    }
  end

  def convert_contact_to_talent(%Contact{whippy_contact: contact}) do
    name = contact["name"] || get_fallback_name(contact["phone"], contact["email"])

    [first_name, last_name] =
      name
      |> StringUtil.parse_contact_name()
      |> Enum.map(fn
        nil -> "unknown"
        "" -> "unknown"
        name -> name
      end)

    %{
      firstName: first_name,
      lastName: last_name,
      mobilePhone: contact["phone"],
      emailAddress: contact["email"],
      origin: "whippy"
    }
  end

  def convert_contact_to_whippy_contact(%Contact{external_contact: external_contact} = contact) do
    external_contact = to_string_keys(external_contact)

    %{
      name: "#{contact.name}",
      phone: contact.phone,
      email: StringUtil.downcase_or_nilify(contact.email),
      external_id: contact.external_contact_id,
      birth_date: parse_date(external_contact["birthday"]),
      address: parse_address(contact.address),
      default_channel_id: contact.whippy_channel_id,
      integration_id: contact.integration_id
    }
  end

  ####################
  ## CUSTOM OBJECTS ##
  ####################

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %Talent{}, custom_object, _extra_params) do
    Enum.map(Talent.to_list_of_custom_properties(), fn custom_property ->
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

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %AvionteContact{}, custom_object, _extra_params) do
    Enum.map(AvionteContact.to_list_of_custom_properties(), fn custom_property ->
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

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %Company{}, custom_object, _extra_params) do
    Enum.map(Company.to_list_of_custom_properties(), fn custom_property ->
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

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %Placement{}, custom_object, _extra_params) do
    Enum.map(Placement.to_list_of_custom_properties(), fn custom_property ->
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

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %Jobs{}, custom_object, _extra_params) do
    Enum.map(Jobs.to_list_of_custom_properties(), fn custom_property ->
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

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_resource_to_custom_object_record(
        integration,
        %Contact{external_contact: talent, whippy_contact_id: whippy_contact_id} = contact,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, talent)
    |> Map.put(:custom_property_values, CustomDataUtil.map_custom_property_values(custom_properties, talent))
    |> Map.put(:whippy_associated_resource_type, "contact")
    |> Map.put(:whippy_associated_resource_id, whippy_contact_id)
    |> Map.put(:external_custom_object_record_id, contact.external_contact_id)
  end

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_resource_to_custom_object_record(
        integration,
        resource,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, resource)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, resource)
    )
    |> Map.put(:external_custom_object_record_id, "#{resource.id}")
  end

  ########################
  ## CUSTOM OBJECTS END ##
  ########################

  defp convert_avionte_user_to_user(%User{
         firstName: first_name,
         lastName: last_name,
         emailAddress: email,
         userId: external_id
       }) do
    %{
      first_name: first_name,
      last_name: last_name,
      email: StringUtil.downcase_or_nilify(email),
      external_user_id: "#{external_id}"
    }
  end

  defp convert_avionte_activity_type_to_activity_type(%TalentActivityType{typeId: external_id, name: name}) do
    %{
      activity_type_id: external_id,
      name: name
    }
  end

  defp convert_avionte_contact_activity_type_to_activity_type(%ContactActivityType{typeId: external_id, name: name}) do
    %{
      activity_type_id: external_id,
      name: name
    }
  end

  defp convert_avionte_branch_to_channel(%Branch{id: external_id} = branch) do
    %{
      external_channel_id: "#{external_id}",
      external_channel: branch
    }
  end

  defp parse_date(birthday) when is_binary(birthday) do
    case NaiveDateTime.from_iso8601(birthday) do
      {:ok, date} -> %{day: date.day, month: date.month, year: date.year}
      _ -> %{}
    end
  end

  defp parse_date(_), do: %{}

  defp parse_address(%{
         "city" => city,
         "street1" => street1,
         "street2" => street2,
         "state_Province" => state,
         "postalCode" => postal_code,
         "country" => country
       }) do
    %{
      address_line_one: street1,
      address_line_two: street2,
      post_code: postal_code,
      country: country,
      state: state,
      city: city
    }
  end

  defp parse_address(_), do: %{}

  defp get_fallback_name(phone, email) do
    if is_nil(phone) and is_nil(email) do
      "No name"
    else
      phone || email
    end
  end

  defp to_string_keys(map) when is_struct(map) do
    map
    |> Map.from_struct()
    |> to_string_keys()
  end

  defp to_string_keys(map) when is_map(map),
    do: Enum.reduce(map, %{}, fn {k, v}, acc -> Map.put(acc, to_string(k), v) end)

  defp to_string_keys(map), do: map
end
