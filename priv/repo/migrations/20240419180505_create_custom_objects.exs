defmodule Sync.Repo.Migrations.CreateCustomObjects do
  use Ecto.Migration

  def change do
    create table(:custom_objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :whippy_custom_object_id, :string
      add :external_custom_object_id, :string
      add :whippy_custom_object, :map
      add :external_custom_object, :map
      add :custom_object_mapping, :map
      add :integration_id, references(:integrations, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:custom_objects, [:integration_id])
  end
end
