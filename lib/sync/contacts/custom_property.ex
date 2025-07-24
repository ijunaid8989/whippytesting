defmodule Sync.Contacts.CustomProperty do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Contacts.CustomObject
  alias Sync.Integrations.Integration

  @required_attrs [
    :integration_id,
    :custom_object_id
  ]

  @cast_attrs [
                :whippy_custom_property,
                :external_custom_property,
                :external_organization_id,
                :external_custom_object_id,
                :whippy_organization_id,
                :whippy_custom_object_id,
                :whippy_custom_property,
                :whippy_custom_property_id,
                :errors,
                :external_custom_property_hash,
                :should_sync_to_whippy
              ] ++ @required_attrs

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_properties" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :whippy_custom_object_id, :string
    field :external_custom_object_id, :string
    field :whippy_custom_property_id, :string
    field :external_custom_property_id, :string
    field :whippy_custom_property, :map
    field :external_custom_property, :map
    field :errors, :map
    field :external_custom_property_hash, :string
    field :should_sync_to_whippy, :boolean, default: false

    belongs_to :custom_object, CustomObject, type: :binary_id
    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(custom_property, attrs) do
    custom_property
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
  end
end
