defmodule Sync.Contacts.CustomObjectRecord do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomPropertyValue
  alias Sync.Integrations.Integration

  @required_attrs [
    :whippy_organization_id,
    :whippy_custom_object_id,
    :integration_id,
    :custom_object_id
  ]

  @cast_attrs [
                :external_organization_id,
                :external_custom_object_id,
                :whippy_custom_object_record,
                :external_custom_object_record,
                :whippy_associated_resource_id,
                :whippy_associated_resource_type,
                :external_associated_resource_id,
                :external_custom_object_record_id,
                :whippy_custom_object_record_id,
                :errors,
                :external_custom_object_record_hash,
                :should_sync_to_whippy
              ] ++ @required_attrs

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_object_records" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :whippy_custom_object_id, :string
    field :external_custom_object_id, :string
    field :whippy_custom_object_record_id, :string
    field :external_custom_object_record_id, :string
    field :whippy_custom_object_record, :map
    field :external_custom_object_record, :map
    field :whippy_associated_resource_id, :string
    field :whippy_associated_resource_type, :string
    field :external_associated_resource_id, :string
    field :errors, :map
    field :external_custom_object_record_hash, :string
    field :should_sync_to_whippy, :boolean, default: false

    belongs_to :custom_object, CustomObject, type: :binary_id
    belongs_to :integration, Integration, type: :binary_id

    has_many :custom_property_values, CustomPropertyValue

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(custom_object_record, attrs) do
    custom_object_record
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(
      [
        :integration_id,
        :custom_object_id,
        :external_custom_object_record_id,
        :whippy_custom_object_record_id
      ],
      name: :custom_object_records_unique_index,
      message: "record already exists"
    )
  end

  def error_changeset(custom_object_record, attrs) do
    cast(custom_object_record, attrs, [:errors, :should_sync_to_whippy])
  end
end
