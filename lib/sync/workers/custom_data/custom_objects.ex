defmodule Sync.Workers.CustomData.CustomObjects do
  @moduledoc """
  Exposes helper functions that create CustomObjects and their properties in the Sync database
  from external resources like Talent, EmployeeDetail, EmployeeAssignment, or a list of CustomData.

  This module is client-agnostic and can be used by any integration to create custom objects from
  an external entity, as long as correct entity_type_to_model_map is provided.

  ## Avionte:
    For example, to create custom objects from Avionte talents, the entity_type_to_model_map would look like:
    %{"talent" => %Sync.Clients.Avionte.Model.Talent{}}

  ## Tempworks:
  To create custom objects for all supported Tempworks entities, the entity_type_to_model_map would look like:
      %{
      "employee" => %Sync.Clients.Tempworks.Model.EmployeeDetail{},
      "assignment" => %Sync.Clients.Tempworks.Model.EmployeeAssignment{},
      "employee_custom_data" => fn integration -> Workers.Tempworks.Reader.get_employee_custom_data(integration) end,
      "assignment_custom_data" => fn integration -> Workers.Tempworks.Reader.get_assignment_custom_data(integration) end
    }

  The last two entries in the map have function values, the reason being that is that the employee_custom_data and assignment_custom_data
  are dynamic and can be different for each Tempworks integration. This means we don't know the exact struct to use for these entities
  until we fetch the data from Tempworks.
  """

  alias Sync.Contacts
  alias Sync.Integrations.Integration
  alias Sync.Workers.CustomData

  require Logger

  @doc """
  Pulls custom objects from the external system and stores them in the Sync database.
  If a custom object already exists, it will update the custom properties.

  ## Parameters
    * `parser_module` - The parser module to use, i.e Sync.Clients.Avionte.Parser or Sync.Clients.Tempworks.Parser.
    * `integration` - The integration to use.
    * `external_entity_type_to_model_map` - A map of external entity types to their corresponding structs or functions that return a structure.

  ## Examples
    iex> pull_custom_objects(Sync.Clients.Avionte.Parser, %Integration{}, %{"talent" => %Sync.Clients.Avionte.Model.Talent{}})
    :ok

  """
  @type entity_type_to_model_map() :: %{String.t() => (Integration.t() -> any()) | struct()}
  @spec pull_custom_objects(
          atom(),
          Integration.t(),
          entity_type_to_model_map()
        ) :: :ok
  def pull_custom_objects(parser_module, %Integration{client: client} = integration, external_entity_type_to_model_map) do
    Enum.each(external_entity_type_to_model_map, fn {external_entity_type, struct_or_func_or_tuple} ->
      case Contacts.list_custom_objects_by_external_entity_type(integration, external_entity_type) do
        [] ->
          create_custom_object(parser_module, integration, external_entity_type, struct_or_func_or_tuple)

        [sync_custom_object] ->
          external_resource = get_external_resource(integration, struct_or_func_or_tuple)

          CustomData.Converter.convert_external_resource_to_custom_properties(
            parser_module,
            integration,
            sync_custom_object,
            external_resource
          )

        _ ->
          client = client |> Atom.to_string() |> String.capitalize()

          Logger.error("""
          [#{client}] [Integration #{integration.id}] Multiple custom objects found for #{external_entity_type}.
          """)
      end
    end)

    :ok
  end

  defp create_custom_object(
         parser_module,
         %Integration{client: client} = integration,
         external_entity_type,
         struct_or_func_or_tuple
       ) do
    attrs = %{
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id,
      whippy_organization_id: integration.whippy_organization_id,
      external_entity_type: external_entity_type,
      external_custom_object: %{
        key: external_entity_type,
        label: external_entity_type |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
      }
    }

    with external_resource when external_resource != nil <- get_external_resource(integration, struct_or_func_or_tuple),
         {:ok, sync_custom_object} <- Contacts.create_custom_object(attrs) do
      CustomData.Converter.convert_external_resource_to_custom_properties(
        parser_module,
        integration,
        sync_custom_object,
        external_resource
      )
    else
      error ->
        client = client |> Atom.to_string() |> String.capitalize()

        Logger.error("""
        [#{client}] [Integration #{integration.id}] Error creating custom object for #{external_entity_type}. Error: #{inspect(error)}
        """)
    end
  end

  defp get_external_resource(integration, get_resource_function) when is_list(get_resource_function) do
    {:list, Enum.map(get_resource_function, fn params -> get_external_resource(integration, params) end)}
  end

  defp get_external_resource(integration, get_resource_function) when is_function(get_resource_function, 1),
    do: get_resource_function.(integration)

  defp get_external_resource(_integration, struct) when is_struct(struct), do: struct
  defp get_external_resource(_integration, _unsupported_value), do: nil
end
