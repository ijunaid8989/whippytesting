defmodule Sync.Clients.Aqore.Parser do
  @moduledoc """
  A module used for defining methods to convert from the data received from
  Aqore into their formatted structs. For example, it will convert a string based
  map into a Candidate struct.
  """

  @behaviour Sync.Behaviours.Clients.CustomDataParser

  alias Sync.Clients.Aqore.Model.AqoreContact
  alias Sync.Clients.Aqore.Model.Candidate
  alias Sync.Clients.Aqore.Model.Comment
  alias Sync.Clients.Aqore.Model.NewCandidate
  alias Sync.Clients.Aqore.Model.User
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Utils.Format.StringUtil
  alias Sync.Utils.Parsers.CustomDataUtil

  require Logger

  def parse(body, type) do
    body
    |> parse!(type)
    |> case do
      {:error, error} -> {:error, error}
      result -> {:ok, result}
    end
  end

  def parse!(%{"access_token" => access_token}, :access_token) do
    access_token
  end

  def parse!(body, :candidates), do: body |> Enum.map(&parse!(&1, :candidate)) |> filter_candidates_with_zzz_name()

  def parse!(body, :candidate), do: body |> Candidate.to_struct!() |> convert_candidate_to_contact()

  def parse!(job_candidates, :job_candidates) do
    job_candidates
    |> Enum.map(&parse_job_candidates/1)
    |> then(fn job_candidates -> %{job_candidates: job_candidates} end)
  end

  def parse!(jobs, :jobs) do
    jobs
    |> Enum.map(&parse_job/1)
    |> then(fn jobs -> %{jobs: jobs} end)
  end

  def parse!(assignments, :assignments) do
    assignments
    |> Enum.map(&parse_assignment/1)
    |> then(fn assignments -> %{assignments: assignments} end)
  end

  def parse!(organization_data, :organization_data) do
    organization_data
    |> Enum.map(&parse_organization_data/1)
    |> then(fn organization_data -> %{organization_data: organization_data} end)
  end

  def parse!(%{"id" => "0", "message" => "Duplicate candidate already exists", "status" => "failed"}, :new_candidate) do
    {:error, "Duplicate candidate already exists"}
  end

  def parse!(body, :new_candidate), do: body |> NewCandidate.to_struct!() |> convert_new_candidate_to_contact()

  def parse!(body, :users), do: Enum.map(body, &parse!(&1, :user))

  def parse!(body, :user), do: body |> User.to_struct!() |> convert_aqore_user_to_contact()

  def parse!(body, :contacts), do: Enum.map(body, &parse!(&1, :contact))

  def parse!(body, :contact), do: body |> AqoreContact.to_struct!() |> convert_aqore_contact_to_sync_contact()

  def parse!(%{"commentId" => comment_id, "success" => success_message} = body, :comment)
      when is_integer(comment_id) and success_message == true do
    Comment.to_struct!(body)
  end

  def parse!(invalid_comment, :comment) do
    metadata = [integration_client: "Aqore", error: invalid_comment]
    Logger.info("Parse invalid_comment", metadata)
    {:error, %{"error" => "unprocessable_entity"}}
  end

  def parse!(error, :error) do
    metadata = [integration_client: "Aqore", error: inspect(error)]
    Logger.error("Parse error", metadata)
    {:error, error}
  end

  def parse!(_body, no_type_match) do
    metadata = [integration_client: "Aqore", error: no_type_match]
    Logger.error("Parse no_type_match", metadata)
    {:error, %{"error" => "unprocessable_entity"}}
  end

  def convert_new_candidate_to_contact(
        %Sync.Clients.Aqore.Model.NewCandidate{id: external_person_id, message: message} = _candidate
      ) do
    %{
      external_contact_id: "#{external_person_id}",
      message: message
    }
  end

  def parse_job_candidates(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    Map.new(atom_based_keys)
  end

  def parse_organization_data(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    Map.new(atom_based_keys)
  end

  def parse_job(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    Map.new(atom_based_keys)
  end

  def parse_assignment(object) do
    atom_based_keys =
      Enum.map(object, fn {k, v} ->
        {String.to_atom(k), v}
      end)

    Map.new(atom_based_keys)
  end

  ####################
  ## CUSTOM OBJECTS ##
  ####################

  @impl Sync.Behaviours.Clients.CustomDataParser
  def convert_external_resource_to_custom_properties(integration, %Candidate{}, custom_object, _extra_params) do
    Enum.map(Candidate.to_list_of_custom_properties(), fn custom_property ->
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

  def convert_external_resource_to_custom_properties(integration, %AqoreContact{}, custom_object, _extra_params) do
    Enum.map(AqoreContact.to_list_of_custom_properties(), fn custom_property ->
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

  def convert_external_resource_to_custom_properties(integration, external_resource, custom_object, _extra_params) do
    Enum.map(external_resource, fn custom_property ->
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
        %Contact{external_contact: candidate, whippy_contact_id: whippy_contact_id} = contact,
        %CustomObject{custom_properties: custom_properties} = custom_object,
        _extra_params
      ) do
    integration
    |> CustomDataUtil.base_custom_data_properties(custom_object, candidate)
    |> Map.put(
      :custom_property_values,
      CustomDataUtil.map_custom_property_values(custom_properties, candidate)
    )
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

  def process_data_to_properties(data, references, whippy_associations) do
    data
    |> convert_keys_to_strings()
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      %{
        key: to_snake_case(key),
        label: format_label(key),
        type: determine_type(value)
      }
    end)
    |> add_references(references)
    |> add_whippy_associations(whippy_associations)
  end

  def process_data_to_properties(data) do
    data
    |> convert_keys_to_strings()
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      %{
        key: to_snake_case(key),
        label: format_label(key),
        type: determine_type(value)
      }
    end)
  end

  defp add_references(data, references_list) do
    Enum.map(data, &merge_reference(&1, references_list))
  end

  defp merge_reference(map, references_list) do
    Enum.reduce(references_list, map, fn %{key: key, type: type}, acc ->
      if acc.key == key do
        new_ref = [%{external_entity_type: type, external_entity_property_key: key, type: "many_to_one"}]
        Map.update(acc, :references, new_ref, &(&1 ++ new_ref))
      else
        acc
      end
    end)
  end

  defp add_whippy_associations(data, whippy_associations) do
    Enum.map(data, &merge_whippy_association(&1, whippy_associations))
  end

  defp merge_whippy_association(map, whippy_associations) do
    Enum.reduce(whippy_associations, map, fn %{source_property_key: key} = whippy_assoc, acc ->
      if acc.key == key do
        Map.update(acc, :whippy_associations, [whippy_assoc], &(&1 ++ [whippy_assoc]))
      else
        acc
      end
    end)
  end

  defp convert_keys_to_strings(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp to_snake_case(key) when is_binary(key) do
    key
    |> to_string()
    |> Macro.underscore()
  end

  defp format_label(key) do
    key |> String.replace(~r/(?<!^)([A-Z])/, " \\1") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp determine_type(value) when is_list(value), do: "list"
  defp determine_type(value) when is_map(value), do: "map"
  defp determine_type(value) when is_integer(value), do: "number"
  defp determine_type(value) when is_float(value), do: "float"
  defp determine_type(value) when is_boolean(value), do: "boolean"

  defp determine_type(value) when is_binary(value) do
    if valid_date?(value) do
      "date"
    else
      "text"
    end
  end

  defp determine_type(_), do: "text"

  defp valid_date?(value) do
    case Date.from_iso8601(value) do
      {:ok, _} ->
        true

      _ ->
        case DateTime.from_iso8601(value) do
          {:ok, _, _} -> true
          _ -> false
        end
    end
  end

  ########################
  ## CUSTOM OBJECTS END ##
  ########################

  defp convert_aqore_user_to_contact(%Sync.Clients.Aqore.Model.User{
         firstName: first_name,
         lastName: last_name,
         email: email,
         id: external_id
       }) do
    %{
      first_name: first_name,
      last_name: last_name,
      email: StringUtil.downcase_or_nilify(email),
      external_user_id: "#{external_id}"
    }
  end

  defp convert_candidate_to_contact(
         %Sync.Clients.Aqore.Model.Candidate{
           firstName: first_name,
           lastName: last_name,
           email: email,
           phone: phone,
           id: external_id,
           dateOfBirth: birth_date
         } = external_candidate
       ) do
    %{
      name: "#{first_name} #{last_name}",
      external_contact_id: "#{external_id}",
      external_contact: external_candidate,
      email: StringUtil.downcase_or_nilify(email),
      phone: phone,
      birth_date: if(birth_date, do: to_string(birth_date)),
      external_organization_entity_type: "candidate",
      address: %{
        city: external_candidate.city,
        address1: external_candidate.address1,
        address2: external_candidate.address2,
        zipCode: external_candidate.zipCode,
        country: external_candidate.country,
        state: external_candidate.state
      }
    }
  end

  defp filter_candidates_with_zzz_name(candidates_list) do
    Enum.reject(candidates_list, fn candidate ->
      case Map.get(candidate.external_contact, :lastName, nil) do
        nil -> false
        last_name -> String.starts_with?(last_name, "zzz")
      end
    end)
  end

  defp convert_aqore_contact_to_sync_contact(
         %Sync.Clients.Aqore.Model.AqoreContact{
           firstName: first_name,
           lastName: last_name,
           email: email,
           phone: phone,
           id: external_id,
           workPhone: work_phone
         } = external_candidate
       ) do
    %{
      name: "#{first_name} #{last_name}",
      external_contact_id: "cont-#{external_id}",
      external_contact: external_candidate,
      email: StringUtil.downcase_or_nilify(email),
      phone: phone || work_phone,
      external_organization_entity_type: "contact"
    }
  end

  def convert_contact_to_whippy_contact(
        %Sync.Contacts.Contact{
          name: name,
          email: email,
          phone: phone,
          external_contact_id: external_id,
          whippy_channel_id: whippy_channel_id,
          integration_id: integration_id
        } = contact
      ) do
    birth_date = parse_date(contact.birth_date)
    address = parse_address(contact.address)

    %{
      name: "#{name}",
      email: StringUtil.downcase_or_nilify(email),
      phone: phone,
      external_id: external_id,
      address: address,
      birth_date: birth_date,
      default_channel_id: whippy_channel_id,
      integration_id: integration_id
    }
  end

  def convert_contact_to_candidate(%Sync.Contacts.Contact{name: name, phone: phone} = contact, %{
        office_name: office_name,
        office_id: office_id
      })
      when not is_nil(phone) do
    [first_name, last_name] = StringUtil.parse_contact_name(name)

    %{
      firstName:
        if first_name == "" do
          phone
        else
          first_name
        end,
      lastName: last_name,
      emailAddress: contact.email,
      mobile: phone,
      office: office_name,
      officeId: office_id
    }
  end

  def convert_contact_to_candidate(%Sync.Contacts.Contact{name: _name, phone: nil}, %{
        office_name: _office_name,
        office_id: _office_id
      }) do
    metadata = [integration_client: "Aqore"]

    Logger.error(
      "Invalid contact in convert_contact_to_candidate. Phone is nil and this is not allowed in Aqore",
      metadata
    )

    {:error, "Invalid contact in convert_contact_to_candidate. Phone is nil and this is not allowed in Aqore"}
  end

  def convert_contact_to_candidate(_invalid_contact) do
    metadata = [integration_client: "Aqore"]
    Logger.error("Invalid contact in convert_contact_to_candidate", metadata)
    {:error, "Invalid contact in convert_contact_to_candidate"}
  end

  defp parse_date(birthday) when not is_nil(birthday) do
    if is_binary(birthday) do
      case Date.from_iso8601(birthday) do
        {:ok, date} -> %{day: date.day, month: date.month, year: date.year}
        _ -> %{}
      end
    else
      %{day: birthday.day, month: birthday.month, year: birthday.year}
    end
  end

  defp parse_date(_), do: %{}

  defp parse_address(address) do
    %{
      address_line_one: address["address1"],
      address_line_two: address["address2"],
      post_code: address["zipCode"],
      country: address["country"],
      state: address["state"],
      city: address["city"]
    }
  end
end
