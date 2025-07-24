defmodule Sync.Behaviours.Clients.CustomDataParser do
  @moduledoc false

  alias Sync.Contacts.CustomObject
  alias Sync.Integrations.Integration

  @type external_custom_property :: %{
          required(:key) => binary(),
          required(:label) => binary(),
          required(:type) => binary()
        }
  @type sync_custom_property_params :: %{
          required(:integration_id) => non_neg_integer(),
          required(:custom_object_id) => non_neg_integer(),
          required(:external_organization_id) => non_neg_integer(),
          required(:whippy_organization_id) => non_neg_integer(),
          required(:whippy_custom_object_id) => non_neg_integer(),
          required(:external_custom_property) => external_custom_property
        }

  @callback convert_external_resource_to_custom_properties(Integration.t(), any(), CustomObject.t(), map()) :: [
              sync_custom_property_params
            ]
  @callback convert_resource_to_custom_object_record(any(), any(), any(), any()) :: any()
end
