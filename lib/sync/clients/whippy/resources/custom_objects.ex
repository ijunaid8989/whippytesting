defmodule Sync.Clients.Whippy.CustomObjects do
  @moduledoc false

  import Sync.Clients.Whippy.Common
  import Sync.Clients.Whippy.Parser, only: [parse: 2]

  alias Sync.Clients.Whippy.Model.CustomObject
  alias Sync.Clients.Whippy.Model.CustomObjectRecord
  alias Sync.Clients.Whippy.Model.CustomProperty

  @custom_object_record_fields [:external_id, :associated_resource_type, :associated_resource_id, :properties]
  @custom_object_fields [:key, :label, :custom_properties, :associations, :whippy_associations]
  @custom_property_fields [:key, :label, :type]

  @type associations_params :: %{
          :type => binary(),
          :source_property_key => binary(),
          :target_property_key => binary(),
          :target_data_type_id => binary()
        }
  @type whippy_associations_params :: %{
          # e.g. "contact"
          :target_whippy_resource => binary(),
          # e.g. "external_id"
          :target_property_key => binary(),
          # e.g. "cont-"
          :target_property_key_prefix => binary() | nil,
          # e.g. "employee_id"
          :source_property_key => binary(),
          # e.g. "one_to_one" or "one_to_many"
          :type => binary()
        }
  @type list_custom_objects_opt :: [limit: non_neg_integer(), offset: non_neg_integer()]
  @type sync_custom_property :: %{
          whippy_custom_object_id: binary(),
          whippy_custom_property: CustomProperty.t()
        }
  @type sync_custom_object :: %{
          whippy_custom_object_id: binary(),
          external_entity_type: binary(),
          whippy_custom_object: CustomObject.t(),
          custom_properties: [sync_custom_property]
        }
  @spec list_custom_objects(binary(), list_custom_objects_opt()) ::
          {:ok, %{custom_objects: [sync_custom_object], total: non_neg_integer()}}
  def list_custom_objects(api_key, opts \\ []) do
    url = "#{get_base_url()}/v1/custom_objects"
    params = Keyword.validate!(opts, [:limit, :offset])

    api_key
    |> request(:get, url, "", params: params)
    |> handle_response(&parse(&1, {:custom_objects, :custom_object}))
  end

  @type custom_property_params :: %{
          :key => binary(),
          :label => binary(),
          :type => String.t()
        }
  @type create_custom_object_params :: %{
          :key => binary(),
          :label => binary(),
          :custom_properties => [custom_property_params()],
          :associations => [associations_params()],
          :whippy_associations => [whippy_associations_params()]
        }
  @spec create_custom_object(binary(), create_custom_object_params()) ::
          {:ok, sync_custom_object} | {:error, term()}
  def create_custom_object(api_key, custom_object) do
    url = "#{get_base_url()}/v1/custom_objects"
    body = custom_object |> Map.take(@custom_object_fields) |> Map.put(:editable, false)

    api_key
    |> request(:post, url, body)
    |> handle_response(&parse(&1, :custom_object))
  end

  @spec update_custom_object(binary(), binary(), create_custom_object_params()) ::
          {:ok, sync_custom_object} | {:error, term()}
  def update_custom_object(api_key, whippy_custom_object_id, custom_object) do
    url = "#{get_base_url()}/v1/custom_objects/#{whippy_custom_object_id}"
    body = custom_object |> Map.take(@custom_object_fields) |> Map.put(:editable, false)

    api_key
    |> request(:put, url, body)
    |> handle_response(&parse(&1, :custom_object))
  end

  @spec create_custom_property(binary(), binary(), custom_property_params()) ::
          {:ok, sync_custom_property} | {:error, term()}
  def create_custom_property(api_key, custom_object_id, custom_property) do
    url = "#{get_base_url()}/v1/custom_objects/#{custom_object_id}/properties"
    body = custom_property |> Map.take(@custom_property_fields) |> Map.put(:editable, false)

    api_key
    |> request(:post, url, body)
    |> handle_response(&parse(&1, :custom_property))
  end

  @spec update_custom_property(binary(), binary(), binary(), custom_property_params()) ::
          {:ok, sync_custom_property} | {:error, term()}
  def update_custom_property(api_key, custom_object_id, custom_property_id, custom_property) do
    url = "#{get_base_url()}/v1/custom_objects/#{custom_object_id}/properties/#{custom_property_id}"
    body = custom_property |> Map.take(@custom_property_fields) |> Map.put(:editable, false)

    api_key
    |> request(:put, url, body)
    |> handle_response(&parse(&1, :custom_property))
  end

  @type create_custom_object_record_params :: %{
          :external_id => binary(),
          optional(:associated_resource_type) => String.t() | nil,
          optional(:associated_resource_id) => String.t() | nil,
          optional(:properties) => map() | nil
        }
  @type sync_custom_property_value :: %{
          whippy_custom_object_record_id: binary(),
          whippy_custom_property_value_id: binary(),
          whippy_custom_property_value: binary()
        }
  @type sync_custom_object_record :: %{
          whippy_custom_object_id: binary(),
          whippy_custom_object_record_id: binary(),
          external_custom_object_record_id: binary(),
          whippy_custom_object_record: CustomObjectRecord.t(),
          custom_property_values: [sync_custom_property_value]
        }
  @spec create_custom_object_record(binary(), binary(), create_custom_object_record_params()) ::
          {:ok, sync_custom_object_record} | {:error, term()}
  def create_custom_object_record(api_key, custom_object_id, record) do
    url = "#{get_base_url()}/v1/custom_objects/#{custom_object_id}/records"
    body = Map.take(record, @custom_object_record_fields)

    api_key
    |> request(:post, url, body)
    |> handle_response(&parse(&1, :custom_object_record))
  end

  @type update_custom_object_record_params :: %{
          optional(:external_id) => binary(),
          optional(:associated_resource_type) => String.t() | nil,
          optional(:associated_resource_id) => String.t() | nil,
          optional(:properties) => map() | nil
        }
  @spec update_custom_object_record(binary(), binary(), binary(), update_custom_object_record_params()) ::
          {:ok, sync_custom_object_record} | {:error, term()}
  def update_custom_object_record(api_key, custom_object_id, record_id, record) do
    url = "#{get_base_url()}/v1/custom_objects/#{custom_object_id}/records/#{record_id}"
    body = Map.take(record, @custom_object_record_fields)

    api_key
    |> request(:put, url, body)
    |> handle_response(&parse(&1, :custom_object_record))
  end
end
