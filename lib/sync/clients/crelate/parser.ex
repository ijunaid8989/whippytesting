defmodule Sync.Clients.Crelate.Parser do
  @moduledoc """
  A module used for defining methods to convert from the data received from
  Crelate into their formatted structs. For example, it will convert a string based
  map into a Address struct.
  """

  alias Sync.Contacts.Contact
  alias Sync.Utils.Format.StringUtil

  def parse_contacts_detail(%{"Data" => objects} = _response) when is_list(objects) do
    Enum.map(objects, fn object ->
      parse_contact_detail(%{"Data" => object})
    end)
  end

  def parse_contact_detail(%{"Data" => object}) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    convert_contact_to_sync_contact(Map.new(atom_based_keys))
  end

  def convert_contact_to_crelate_contact(contact) do
    %{
      entity: convert_to_crelate_contact(contact)
    }
  end

  def convert_contact_to_crelate_bulk_contacts(contacts) do
    parsed_contacts =
      Enum.map(contacts, fn contact ->
        convert_to_crelate_contact(contact)
      end)

    %{
      entities: parsed_contacts
    }
  end

  defp convert_to_crelate_contact(%Contact{whippy_contact: contact} = _contact) do
    [first_name, last_name] = StringUtil.parse_contact_name(contact["name"])

    %{
      FirstName: first_name,
      LastName: last_name,
      PhoneNumbers_Mobile: %{
        Extension: "+1",
        IsPrimary: true,
        Value: contact["phone"]
      },
      EmailAddresses_Personal: %{
        IsPrimary: true,
        Value: contact["email"]
      }
    }
  end

  defp convert_contact_to_sync_contact(contact) do
    name =
      [
        Map.get(contact, :FirstName, ""),
        Map.get(contact, :LastName, "")
      ]
      |> Enum.reject(&nil_or_empty/1)
      |> Enum.join(" ")
      |> case do
        # Fallback to :Name if first & last names are empty
        "" -> Map.get(contact, :Name, "")
        valid_name -> valid_name
      end

    {phone_field, phone_number} = get_phone_number(contact)

    email = get_nested_value(contact, [:EmailAddresses_Personal, "Value"])
    birth_date = get_nested_value(contact, [:KeyDates_Birthday, "Value"])
    address = parse_address(Map.get(contact, :Addresses_Home, %{}))

    %{
      external_contact_id: Map.get(contact, :Id, nil),
      phone: phone_number,
      name: name,
      email: email,
      birth_date: birth_date,
      address: address,
      external_contact:
        Map.put(
          %{
            Name: name,
            FirstName: Map.get(contact, :FirstName, nil),
            MiddleName: Map.get(contact, :MiddleName, nil),
            LastName: Map.get(contact, :LastName, nil),
            Id: Map.get(contact, :Id, nil),
            EmailAddresses_Personal: email,
            KeyDates_Birthday: birth_date,
            Addresses_Home: address
          },
          phone_field,
          phone_number
        )
    }
  end

  defp nil_or_empty(value), do: value in [nil, ""]

  defp get_phone_number(contact) do
    phone_fields = [
      :PhoneNumbers_Mobile,
      :PhoneNumbers_Home,
      :PhoneNumbers_Mobile_Other,
      :PhoneNumbers_Other,
      :PhoneNumbers_Other_Alternate,
      :PhoneNumbers_Potential,
      :PhoneNumbers_Work_Direct,
      :PhoneNumbers_Work_Main,
      :PhoneNumbers_Work_Other,
      :PhoneNumbers_Skype
    ]

    Enum.reduce_while(phone_fields, nil, fn field, _acc ->
      value = get_nested_value(contact, [field, "Value"])

      if value do
        {:halt, {field, value}}
      else
        {:cont, {field, nil}}
      end
    end)
  end

  def get_nested_value(map, keys) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case acc do
        nil -> {:halt, nil}
        _ -> {:cont, Map.get(acc, key, nil)}
      end
    end)
  end

  def convert_contact_to_whippy_contact(contact) do
    %{
      name: "#{contact.name}",
      phone: contact.phone,
      email: StringUtil.downcase_or_nilify(contact.email),
      external_id: contact.external_contact_id,
      birth_date: parse_date(contact.birth_date),
      address: contact.address,
      integration_id: contact.integration_id
    }
  end

  def parse_address(
        %{"City" => city, "CountryId" => %{"Title" => country_title}, "State" => state, "ZipCode" => postal_code} =
          address
      ) do
    %{
      address_line_one: Map.get(address, "Line1", nil),
      address_line_two: Map.get(address, "Line2", nil),
      post_code: postal_code,
      country: country_title,
      state: state,
      city: city
    }
  end

  def parse_address(_), do: %{}

  defp parse_date(birthday) when is_binary(birthday) do
    case NaiveDateTime.from_iso8601(birthday) do
      {:ok, date} -> %{day: date.day, month: date.month, year: date.year}
      _ -> %{}
    end
  end

  defp parse_date(_), do: %{}
end
