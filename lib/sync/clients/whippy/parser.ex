defmodule Sync.Clients.Whippy.Parser do
  @moduledoc """
  A module used for defining methods to convert from the data received from
  Whippy into their formatted structs.
  """

  alias Sync.Clients.Whippy.Model.Channel
  alias Sync.Clients.Whippy.Model.Contact
  alias Sync.Clients.Whippy.Model.Conversation
  alias Sync.Clients.Whippy.Model.CustomObject
  alias Sync.Clients.Whippy.Model.CustomObjectRecord
  alias Sync.Clients.Whippy.Model.CustomProperty
  alias Sync.Clients.Whippy.Model.User
  alias Sync.Utils.Format.StringUtil

  def parse(object, type) do
    {:ok, parse!(object, type)}
  end

  def convert_whippy_message_to_sync_activity(
        %{"id" => whippy_activity_id, "contact_id" => whippy_contact_id, "user_id" => user_id, "created_at" => created_at} =
          message
      ) do
    {:ok, whippy_activity_inserted_at, _offset} = DateTime.from_iso8601(created_at)

    activity_type = Map.get(%{"sms" => "message", "email" => "email", "call" => "call"}, message["type"], "message")

    %{
      whippy_contact_id: whippy_contact_id,
      whippy_activity_id: whippy_activity_id,
      whippy_activity: message,
      activity_type: activity_type,
      whippy_user_id: "#{user_id}",
      whippy_activity_inserted_at: whippy_activity_inserted_at
    }
  end

  def convert_channel_to_sync_channel(%Channel{id: whippy_channel_id, timezone: timezone}) do
    %{
      whippy_channel_id: whippy_channel_id,
      timezone: timezone
    }
  end

  def convert_custom_object_record_to_whippy_custom_object_record(
        %Sync.Contacts.CustomObjectRecord{} = custom_object_record
      ) do
    # Some values might be decoded from JSON to integers, booleans, etc when they are stored in the database.
    # But whippy might expect them as strings or floats, so we need to convert them back to the whippy type, if needed.
    parse_custom_value = fn
      value, "text" -> to_string(value)
      value, "float" -> parse_float(value)
      value, "date" -> parse_date(value)
      value, _type -> value
    end

    %{
      custom_object_id: custom_object_record.whippy_custom_object_id,
      external_id: custom_object_record.external_custom_object_record_id,
      associated_resource_id: custom_object_record.whippy_associated_resource_id,
      associated_resource_type: custom_object_record.whippy_associated_resource_type,
      properties:
        Map.new(custom_object_record.custom_property_values, fn custom_property_value ->
          {custom_property_value.custom_property.whippy_custom_property["key"],
           parse_custom_value.(
             custom_property_value.external_custom_property_value,
             custom_property_value.custom_property.whippy_custom_property["type"]
           )}
        end)
    }
  end

  defp convert_whippy_contact_to_sync_contact(
         %Contact{id: whippy_contact_id, phone: phone, name: name, email: email} = contact
       ) do
    %{
      whippy_contact_id: whippy_contact_id,
      phone: phone,
      name: name,
      email: email,
      whippy_contact: contact
    }
  end

  defp convert_whippy_user_to_sync_user(%User{id: whippy_user_id, name: name, email: email}) do
    %{
      whippy_user_id: "#{whippy_user_id}",
      name: name,
      email: StringUtil.downcase_or_nilify(email)
    }
  end

  defp convert_whippy_custom_object_to_sync_custom_object(%CustomObject{} = custom_object) do
    %{
      # It is expected that the custom object has a key that exactly matches the name of the external entity type, i.e "employee", "assignment"
      external_entity_type: custom_object.key,
      whippy_custom_object_id: custom_object.id,
      whippy_custom_object: custom_object,
      custom_properties:
        Enum.map(
          custom_object.custom_properties,
          &convert_whippy_custom_property_to_sync_custom_property/1
        )
    }
  end

  defp convert_whippy_custom_property_to_sync_custom_property(%CustomProperty{} = custom_property) do
    %{
      whippy_custom_object_id: custom_property.custom_object_id,
      whippy_custom_property_id: custom_property.id,
      whippy_custom_property: custom_property
    }
  end

  defp convert_whippy_custom_object_record_to_sync_custom_object_record(%CustomObjectRecord{} = custom_object_record) do
    %{
      whippy_custom_object_id: custom_object_record.custom_object_id,
      whippy_custom_object_record_id: custom_object_record.id,
      external_custom_object_record_id: custom_object_record.external_id,
      whippy_custom_object_record: custom_object_record,
      custom_property_values: []
    }
  end

  def convert_custom_object_to_whippy_custom_object(%Sync.Contacts.CustomObject{} = custom_object) do
    %{
      key: custom_object.external_custom_object["key"],
      label: custom_object.external_custom_object["label"]
    }
    |> Map.put(
      :custom_properties,
      Enum.map(custom_object.custom_properties, &convert_custom_property_to_whippy_custom_property/1)
    )
    |> maybe_add_whippy_associations(custom_object)
  end

  def convert_custom_property_to_whippy_custom_property(%Sync.Contacts.CustomProperty{} = custom_property) do
    %{
      key: custom_property.external_custom_property["key"],
      label: custom_property.external_custom_property["label"],
      type: custom_property.external_custom_property["type"]
    }
  end

  # A Sync Custom Object could have `whippy_associations` defined in its `whippy_custom_object` field or
  # in the `external_custom_property` field of each of its `custom_properties`.
  # This function combines both sources of whippy_ssociations into a single list, ensuring that there are no duplicates.
  # The resulting output is a `custom_object_map` that contains the `whippy_associations` key if any associations are found.
  # The map is in a format that is ready to be sent to Whippy to create or update a custom object.
  defp maybe_add_whippy_associations(custom_object_map, custom_object) do
    whippy_custom_object = Map.get(custom_object, :whippy_custom_object) || %{}
    whippy_associations = whippy_custom_object["whippy_associations"] || []

    external_associations =
      Enum.flat_map(custom_object.custom_properties, fn cp ->
        cp.external_custom_property["whippy_associations"] || []
      end)

    combined_associations = Enum.uniq_by(whippy_associations ++ external_associations, & &1["source_property_key"])

    if combined_associations != [] do
      Map.put(custom_object_map, :whippy_associations, combined_associations)
    else
      custom_object_map
    end
  end

  # Returns a map with the parsed resource and the total number of resources (if total is present),
  # iex> parse!(%{"data" => [%{"id" => 1}]}, {:users, :user})
  # %{users: [%User{id: 1}], total: 1}
  defp parse!(%{"data" => list} = decoded_response, {type_plural, type_singular}) when is_list(list) do
    map_with_parsed_resource = %{type_plural => Enum.map(list, &parse!(&1, type_singular))}

    case Map.get(decoded_response, "total") do
      nil -> map_with_parsed_resource
      total -> Map.put(map_with_parsed_resource, :total, total)
    end
  end

  defp parse!(object, :conversation) do
    conversation = Map.get(object, "data", object)
    atom_based_keys = Enum.map(conversation, fn {k, v} -> {String.to_atom(k), v} end)

    struct!(Conversation, atom_based_keys)
  end

  defp parse!(object, :contact) do
    contact = Map.get(object, "data", object)
    atom_based_keys = Enum.map(contact, fn {k, v} -> {String.to_atom(k), v} end)

    Contact
    |> struct!(atom_based_keys)
    |> convert_whippy_contact_to_sync_contact()
  end

  defp parse!(object, :user) do
    atom_based_keys = Enum.map(object, fn {k, v} -> {String.to_atom(k), v} end)

    User
    |> struct!(atom_based_keys)
    |> convert_whippy_user_to_sync_user()
  end

  defp parse!(object, :channel) do
    channel = Map.get(object, "data", object)
    atom_based_keys = Enum.map(channel, fn {k, v} -> {String.to_atom(k), v} end)

    struct!(Channel, atom_based_keys)
  end

  defp parse!(object, :custom_object_record) do
    object
    |> Map.get("data", object)
    |> CustomObjectRecord.to_struct!()
    |> convert_whippy_custom_object_record_to_sync_custom_object_record()
  end

  defp parse!(object, :custom_object) do
    object
    |> Map.get("data", object)
    |> CustomObject.to_struct!()
    |> convert_whippy_custom_object_to_sync_custom_object()
  end

  defp parse!(object, :custom_property) do
    object
    |> Map.get("data", object)
    |> CustomProperty.to_struct!()
    |> convert_whippy_custom_property_to_sync_custom_property()
  end

  defp parse!(object, :send_sms) do
    Map.get(object, "data", object)
  end

  defp parse_float(nil), do: nil

  defp parse_float(value) do
    case value |> to_string() |> Float.parse() do
      {value, _} -> value
      _ -> nil
    end
  end

  # For now this just ensures that no empty string are sent to Whippy for custom data dates.
  # In the future this can be extended to convert the value to specific date/datetime formats
  defp parse_date(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp parse_date(value), do: value
end
