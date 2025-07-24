defmodule Sync.Clients.Loxo.Parser do
  @moduledoc false

  alias Sync.Clients.Loxo.Model.ActivityType
  alias Sync.Clients.Loxo.Model.Person
  alias Sync.Clients.Loxo.Model.PersonEvent
  alias Sync.Clients.Loxo.Model.Users
  alias Sync.Contacts.Contact
  alias Sync.Utils.Format.StringUtil

  require Logger

  def parse(body, type) do
    {:ok, parse!(body, type)}
  end

  def parse!(body, :activity_type), do: body |> ActivityType.to_struct!() |> convert_loxo_activity_type_to_activity_type()

  def parse!(body, :activity_types), do: Enum.map(body, &parse!(&1, :activity_type))

  def parse!(body, :person) do
    body
    |> Person.to_struct!()
    |> convert_person_to_contact()
  end

  def parse!(body, :people) when is_list(body) do
    Enum.map(body, &parse!(&1, :person))
  end

  def parse!(body, :person_event) do
    PersonEvent.to_struct!(body)
  end

  def parse!(body, :users) do
    Enum.map(body, &parse!(&1, :user))
  end

  def parse!(body, :user) do
    body
    |> Users.to_struct!()
    |> convert_loxo_user_to_contact()
  end

  def parse!({:ok, %HTTPoison.Response{status_code: 400, body: error_body}}, :error) do
    {:error, Jason.decode!(error_body)}
  end

  def parse!(error, _type), do: error

  defp convert_loxo_user_to_contact(%Sync.Clients.Loxo.Model.Users{name: name, email: email, id: external_id}) do
    [first_name, last_name] = StringUtil.parse_contact_name(name)

    %{
      first_name: first_name,
      last_name: last_name,
      email: StringUtil.downcase_or_nilify(email),
      external_user_id: "#{external_id}"
    }
  end

  defp convert_loxo_activity_type_to_activity_type(%ActivityType{id: activity_type_id, name: name}) do
    %{
      activity_type_id: activity_type_id,
      name: name
    }
  end

  # Contacts are called person/people in Loxo
  def convert_person_to_contact(
        %Sync.Clients.Loxo.Model.Person{
          id: external_person_id,
          name: name,
          emails: list_of_emails,
          phones: list_of_phones
        } = person
      ) do
    first_email = parse_email(list_of_emails)
    first_phone = parse_phone(list_of_phones)

    %{
      name: name,
      external_contact_id: "#{external_person_id}",
      external_contact: person,
      email: StringUtil.downcase_or_nilify(first_email),
      phone: first_phone,
      external_organization_entity_type: "person"
    }
  end

  def convert_person_to_contact(%{} = person) do
    Logger.error("Invalid person object provided to convert_person_to_contact, #{inspect(person)}")

    %{}
  end

  def convert_contact_to_whippy_contact(
        %Contact{
          name: name,
          email: email,
          phone: phone,
          external_contact_id: external_contact_id,
          integration_id: integration_id
        } = _contact
      ) do
    %{
      name: "#{name}",
      phone: phone,
      email: email,
      external_id: external_contact_id,
      integration_id: integration_id
    }
  end

  @doc """
  This function converts Whippy Contact to a simpler map that can be used to create a person in Loxo.
  The form to submit to create a person in Loxo is different from the response structure
  This function makes it easier to build the query that is sent to Loxo
  """
  def convert_contact_to_person(%Contact{name: name, email: email, phone: phone} = _contact) do
    fallback_name = get_fallback_name(phone, email)

    %{
      name: name || fallback_name,
      email: email || "",
      phone: phone || ""
    }
  end

  def convert_contact_to_person(invalid_payload) do
    Logger.error("Invalid payload provided to convert_contact_to_person: #{inspect(invalid_payload)}")

    %{}
  end

  ####################
  # Helper Functions #
  ####################

  # phone -> email -> "No name"
  defp get_fallback_name(phone, email) do
    if is_nil(phone) and is_nil(email) do
      "No name"
    else
      phone || email
    end
  end

  defp parse_email(email) do
    parse_first_value(email)
  end

  defp parse_phone(phone) do
    parse_first_value(phone)
  end

  # Extracts the first value from a list of objects
  # eg phones: [{"value" => "123-456-7890", ... }, {"value" => "567-765-4321", ...}, ...]
  # returns "123-456-7890"
  defp parse_first_value([%{"value" => valid_object_value} | _]) do
    valid_object_value
  end

  defp parse_first_value([]) do
    nil
  end

  defp parse_first_value(_other) do
    nil
  end
end
