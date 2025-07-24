defmodule Sync.Repo.Migrations.CreateCustomObjectRecords do
  use Ecto.Migration

  def change do
    create table(:custom_object_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :whippy_custom_object_id, :string
      add :external_custom_object_id, :string
      add :whippy_custom_object_record, :map
      add :external_custom_object_record, :map
      add :whippy_associated_resource_id, :string
      add :external_associated_resource_id, :string
      add :integration_id, references(:integrations, on_delete: :nothing, type: :binary_id)
      add :custom_object_id, references(:custom_objects, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:custom_object_records, [:integration_id])
    create index(:custom_object_records, [:custom_object_id])
  end
end
