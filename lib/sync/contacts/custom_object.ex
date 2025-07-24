defmodule Sync.Contacts.CustomObject do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  @required_attrs [
    :integration_id,
    :whippy_organization_id
  ]

  @cast_attrs [
                :whippy_custom_object,
                :external_custom_object,
                :custom_object_mapping,
                :external_entity_type,
                :external_organization_id,
                :external_custom_object_id,
                :whippy_custom_object_id,
                :errors
              ] ++ @required_attrs

  @supported_entity_types_per_client %{
    tempworks: [
      "employee",
      "assignment",
      "tempworks_contacts",
      "job_orders",
      "customers"
    ],
    avionte: ["talent", "avionte_contact", "companies", "placements", "jobs"],
    aqore: ["candidate", "job_candidate", "job", "assignment", "aqore_contact", "organization_data"]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_objects" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :whippy_custom_object_id, :string
    field :external_custom_object_id, :string
    field :whippy_custom_object, :map
    field :external_custom_object, :map
    field :custom_object_mapping, :map
    field :external_entity_type, :string
    field :errors, :map

    belongs_to :integration, Integration, type: :binary_id
    has_many :custom_properties, CustomProperty
    has_many :custom_object_records, CustomObjectRecord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(custom_object, attrs) do
    custom_object
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
    |> assoc_constraint(:integration)
    |> unique_constraint(
      [
        :integration_id,
        :external_custom_object_id,
        :whippy_custom_object_id
      ],
      name: :custom_objects_unique_index,
      message: "record already exists"
    )
    |> validate_supported_entity_type()
  end

  defp validate_supported_entity_type(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_supported_entity_type(changeset) do
    external_entity_type = get_field(changeset, :external_entity_type)
    integration_id = get_field(changeset, :integration_id)
    integration = Integrations.get_integration(integration_id)

    case Map.get(@supported_entity_types_per_client, integration.client) do
      nil ->
        add_error(
          changeset,
          :external_entity_type,
          "no external entity types supported for integration with #{integration.client}"
        )

      supported_entity_types ->
        if external_entity_type in supported_entity_types do
          changeset
        else
          put_change(changeset, :external_entity_type, "custom_data")
        end
    end
  end
end
