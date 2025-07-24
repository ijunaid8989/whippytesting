defmodule Sync.Contacts.CustomPropertyValue do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Integrations.Integration
  alias Sync.Utils.Ecto.SerializedValue

  @required_attrs [
    :custom_object_record_id,
    :custom_property_id,
    :whippy_organization_id,
    :whippy_custom_property_id
  ]

  @cast_attrs [
                :integration_id,
                :external_organization_id,
                :external_custom_object_record_id,
                :external_custom_property_value_id,
                :external_custom_property_value,
                :external_custom_property_id,
                :whippy_custom_object_record_id,
                :whippy_custom_property_value_id,
                :whippy_custom_property_value,
                :errors
              ] ++ @required_attrs

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_property_values" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :whippy_custom_object_record_id, :string
    field :external_custom_object_record_id, :string
    field :whippy_custom_property_value_id, :string
    field :external_custom_property_value_id, :string
    field :whippy_custom_property_id, :string
    field :external_custom_property_id, :string
    field :whippy_custom_property_value, SerializedValue
    field :external_custom_property_value, SerializedValue
    field :errors, :map

    belongs_to :custom_object_record, CustomObjectRecord, type: :binary_id
    belongs_to :custom_property, CustomProperty, type: :binary_id
    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(custom_property_values, attrs) do
    custom_property_values
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
  end
end
