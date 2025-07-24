defmodule Sync.Workers.CustomData.Converter do
  @moduledoc """
  Exposes functions for converting data to custom object records or custom properties.
  """

  import Ecto.Query

  alias Sync.Contacts
  alias Sync.Contacts.CustomObjectRecord

  require Logger

  ###########################
  ####  Custom Objects  #####
  ###########################

  @doc """
  Converts external resources like a Talent, EmployeeDetail or a list of CustomData to custom properties and associates them with
  the given custom object.

  ## Parameters
    * `parser_module` - The parser module to use, i.e Sync.Clients.Avionte.Parser or Sync.Clients.Tempworks.Parser.
    * `integration` - The integration to use.
    * `custom_object` - The custom object to associate the custom properties with.
    * `external_resource` - The external resource to convert to custom properties. This can be a Talent, EmployeeDetail, EmployeeAssignment,
      or a map like %{custom_data: [%CustomData{}]}.

  ## Examples
    iex> convert_external_resource_to_custom_properties(integration, custom_object, employee_detail)
     {:ok, %{skip_or_create_employee_id: %CustomProperty{}, skip_or_create_employee_name: nil}}

    iex> convert_external_resource_to_custom_properties(integration, custom_object, custom_data)
     {:error, :skip_or_create_employee_address, %Ecto.Changeset{}, %{}}
  """
  @spec convert_external_resource_to_custom_properties(
          atom(),
          Integration.t(),
          CustomObject.t(),
          map()
        ) :: {:ok, map()} | {:error, :function_not_implemented_for_parser_module}
  def convert_external_resource_to_custom_properties(_parser_module, _integration, _custom_object, nil), do: {:ok, %{}}

  def convert_external_resource_to_custom_properties(
        parser_module,
        integration,
        custom_object,
        {:list, external_resources}
      ) do
    if function_exists?(parser_module, {:convert_external_resource_to_custom_properties, 4}) do
      external_resources
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn external_resource ->
        parser_module.convert_external_resource_to_custom_properties(integration, external_resource, custom_object, %{})
      end)
      |> Contacts.create_external_custom_properties()
    else
      {:error, :function_not_implemented_for_parser_module}
    end
  end

  def convert_external_resource_to_custom_properties(parser_module, integration, custom_object, external_resource) do
    if function_exists?(parser_module, {:convert_external_resource_to_custom_properties, 4}) do
      integration
      |> parser_module.convert_external_resource_to_custom_properties(external_resource, custom_object, %{})
      |> Contacts.create_external_custom_properties()
    else
      {:error, :function_not_implemented_for_parser_module}
    end
  end

  ##################################
  ####  Custom Object Records  #####
  ##################################

  @doc """
  Converts an external resource to a custom object record and associates it with the given custom object.

  ## Parameters
    * `parser_module` - The parser module to use, i.e Sync.Clients.Avionte.Parser or Sync.Clients.Tempworks.Parser.
    * `integration` - The integration to use.
    * `custom_object` - The custom object to associate the custom object record with.
    * `external_resource` - The external resource to convert to a custom object record.

  ## Examples
    iex> convert_external_resource_to_custom_object_record(parser_module, integration, custom_object, employee_detail)
     %CustomObjectRecord{custom_object_id: 1, external_id: 123, custom_property_values: [%CustomPropertyValue{}]}
  """
  @spec convert_external_resource_to_custom_object_record(
          atom(),
          Integration.t(),
          CustomObject.t(),
          any(),
          map()
        ) ::
          {:ok, CustomObjectRecord.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :function_not_implemented_for_parser_module}
  def convert_external_resource_to_custom_object_record(
        parser_module,
        integration,
        custom_object,
        external_resource,
        extra_params \\ %{}
      ) do
    if function_exists?(parser_module, {:convert_resource_to_custom_object_record, 4}) do
      integration
      |> parser_module.convert_resource_to_custom_object_record(external_resource, custom_object, extra_params)
      |> Contacts.create_custom_object_record_with_custom_property_values()
    else
      {:error, :function_not_implemented_for_parser_module}
    end
  end

  @doc """
  Converts multiple external resources to custom object records and associates them with the given custom object.

  ## Parameters
    * `parser_module` - The parser module to use, i.e Sync.Clients.Avionte.Parser or Sync.Clients.Tempworks.Parser.
    * `integration` - The integration to use.
    * `custom_object` - The custom object to associate the custom object records with.
    * `external_resources` - The list of external resources to convert to custom object records.
    * `extra_params` - Additional parameters to pass to the conversion function.

  ## Examples
    iex> convert_bulk_external_resource_to_custom_object_record(parser_module, integration, custom_object, [employee_detail1, employee_detail2])
     {:ok, %CustomObjectRecord{}}
  """
  @spec convert_bulk_external_resource_to_custom_object_record(
          atom(),
          Integration.t(),
          CustomObject.t(),
          list(),
          map()
        ) ::
          {:ok, CustomObjectRecord.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :function_not_implemented_for_parser_module}
  def convert_bulk_external_resource_to_custom_object_record(
        parser_module,
        integration,
        custom_object,
        external_resources,
        extra_params \\ %{}
      ) do
    if function_exists?(parser_module, {:convert_resource_to_custom_object_record, 4}) do
      results =
        process_each_external_resource(parser_module, integration, custom_object, external_resources, extra_params)

      # Create the custom object record with the merged results
      Contacts.create_custom_object_record_with_custom_property_values(results)
    else
      {:error, :function_not_implemented_for_parser_module}
    end
  end

  @doc """
  Lists all sync Contacts that are synced between the external system and Whippy, but have not been converted to
  custom object records yet. It then converts them to custom object records using the given parser module.

  ## Parameters
    * `parser_module` - The parser module to use, i.e Sync.Clients.Avionte.Parser or Sync.Clients.Tempworks.Parser.
    * `integration` - The integration to use.
    * `custom_object` - The custom object to convert the external contacts to.

  ## Examples
    iex> convert_external_contacts_to_custom_object_records(Sync.Clients.Avionte.Parser, integration, custom_object)
     [{:ok, %CustomObjectRecord{}}, ...]
  """
  @spec convert_external_contacts_to_custom_object_records(
          atom(),
          Integration.t(),
          CustomObject.t(),
          term()
        ) :: [{:ok, CustomObjectRecord.t()} | {:error, Ecto.Changeset.t()}]
  def convert_external_contacts_to_custom_object_records(
        parser_module,
        integration,
        custom_object,
        condition \\ dynamic(true)
      ) do
    if function_exists?(parser_module, {:convert_resource_to_custom_object_record, 4}) do
      limit = 100

      contacts =
        Contacts.list_contacts_not_converted_to_custom_object_records(integration, limit, custom_object.id, condition)

      if Enum.count(contacts) < limit do
        do_convert_contacts_to_custom_object_records(parser_module, integration, custom_object, contacts)
      else
        do_convert_contacts_to_custom_object_records(parser_module, integration, custom_object, contacts)

        convert_external_contacts_to_custom_object_records(parser_module, integration, custom_object, condition)
      end
    else
      {:error, :function_not_implemented_for_parser_module}
    end
  end

  defp do_convert_contacts_to_custom_object_records(parser_module, integration, employee_custom_object, contacts) do
    contacts
    |> Enum.map(fn contact ->
      parser_module.convert_resource_to_custom_object_record(integration, contact, employee_custom_object, %{})
    end)
    |> Enum.map(&Contacts.create_custom_object_record_with_custom_property_values/1)
  end

  defp function_exists?(module, function) do
    function in module.module_info(:exports)
  end

  defp process_each_external_resource(parser_module, integration, custom_object, external_resources, extra_params) do
    # Process each external resource and collect the results
    Enum.reduce(external_resources, %{}, fn external_resource, acc ->
      case parser_module.convert_resource_to_custom_object_record(
             integration,
             external_resource,
             custom_object,
             extra_params
           ) do
        nil ->
          acc

        result when is_map(result) ->
          handle_merge_results(acc, result)

        _ ->
          acc
      end
    end)
  end

  defp handle_merge_results(acc, result) do
    # Merge the results, handling custom_property_values specially
    Map.merge(acc, result, fn
      :custom_property_values, existing_values, new_values ->
        process_values(existing_values, new_values)

      :external_custom_object_record, _existing, new when not is_nil(new) ->
        new

      _key, existing, _new ->
        existing
    end)
  end

  defp process_values(existing_values, new_values) do
    # Combine values and ensure no duplicates based on custom_property_id
    (existing_values ++ new_values)
    |> Enum.filter(fn value -> value.external_custom_property_value != nil end)
    |> Enum.uniq_by(& &1.custom_property_id)
  end
end
