defmodule Sync.Repo.Migrations.CreateCustomPropertyValues do
  use Ecto.Migration

  def change do
    create table(:custom_property_values, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :whippy_custom_object_record_id, :string
      add :external_custom_object_record_id, :string
      add :whippy_custom_property_value_id, :string
      add :external_custom_property_value_id, :string
      add :whippy_custom_property_value, :text
      add :external_custom_property_value, :text
      add :integration_id, references(:integrations, on_delete: :nothing, type: :binary_id)

      add :custom_object_record_id,
          references(:custom_object_records, on_delete: :nothing, type: :binary_id)

      add :custom_property_id,
          references(:custom_properties, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:custom_property_values, [:integration_id])
    create index(:custom_property_values, [:custom_object_record_id])
    create index(:custom_property_values, [:custom_property_id])
  end
end
