defmodule Sync.Utils.Parsers.CustomDataUtil do
  @moduledoc false

  require Logger

  @doc """
  Generates a map of base custom data properties for a given integration, custom object, and external resource.

  ## Parameters

    - `integration`: The integration struct containing integration details.
    - `custom_object`: The custom object struct containing custom object details.
    - `external_resource`: The external resource associated with the custom object.

  ## Returns

    A map containing the following keys:
    - `:integration_id` - The ID of the integration.
    - `:external_organization_id` - The external organization ID associated with the integration.
    - `:whippy_organization_id` - The Whippy organization ID associated with the custom object.
    - `:whippy_custom_object_id` - The Whippy custom object ID.
    - `:custom_object_id` - The ID of the custom object.
    - `:external_custom_object_record` - The external resource associated with the custom object.
  """
  def base_custom_data_properties(integration, custom_object, external_resource) do
    %{
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id,
      whippy_organization_id: custom_object.whippy_organization_id,
      whippy_custom_object_id: custom_object.whippy_custom_object_id,
      custom_object_id: custom_object.id,
      external_custom_object_record: external_resource
    }
  end

  @doc """
  Maps custom properties to their corresponding values from an external resource.

  ## Parameters

    - `sync_custom_properties`: A list of custom properties to be mapped.
    - `external_resource`: The external resource containing the values for the custom properties.

  ## Returns

    A list of maps where each map contains:
    - `:custom_property_id` - The ID of the custom property.
    - `:integration_id` - The ID of the integration.
    - `:whippy_custom_property_id` - The Whippy custom property ID.
    - `:external_custom_property_value` - The value of the custom property from the external resource.

  ## Example
        iex> sync_custom_properties = [%CustomProperty{id: "1", integration_id: "1", whippy_custom_property_id: "1", whippy_custom_property: %{"key" => "employee_id"}}, %CustomProperty{id: "2", integration_id: "1", whippy_custom_property_id: "2", whippy_custom_property: %{"key" => "first_name"}}]
        iex> external_resource = %{"employeeId" => "123", "firstName" => "John Doe"}
        iex> map_custom_property_values(sync_custom_properties, external_resource)
        [
          %{
            custom_property_id: "1",
            integration_id: "1",
            whippy_custom_property_id: "1",
            external_custom_property_value: "123"
          },
          %{
            custom_property_id: "2",
            integration_id: "1",
            whippy_custom_property_id: "2",
            external_custom_property_value: "John Doe"
          }
        ]

  """
  @type custom_property_value_map :: %{
          custom_property_id: String.t(),
          integration_id: String.t(),
          whippy_custom_property_id: String.t(),
          external_custom_property_value: any()
        }

  @spec map_custom_property_values([CustomProperty.t()], map()) :: [custom_property_value_map()]
  def map_custom_property_values(sync_custom_properties, external_resource) do
    sync_custom_properties
    |> Enum.reject(fn map ->
      if map.whippy_custom_property == nil do
        Logger.error(
          "[Custom data] whippy custom property key is nil for whippy custom property id #{map.whippy_custom_property_id}"
        )

        true
      else
        false
      end
    end)
    |> Enum.map(&convert_resource_value_to_custom_property_value(external_resource, &1))
  end

  defp convert_resource_value_to_custom_property_value(resource, custom_property) do
    resource = to_string_keys(resource)
    # employee_id -> employeeId
    [head | tail] = String.split(custom_property.whippy_custom_property["key"], "_")
    resource_key = head <> Enum.join(Enum.map(tail, &String.capitalize/1))

    %{
      custom_property_id: custom_property.id,
      integration_id: custom_property.integration_id,
      external_organization_id: custom_property.external_organization_id,
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
end
