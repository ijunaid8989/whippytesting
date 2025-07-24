defmodule Sync.Repo.Migrations.AddWhippyAndExternalCustomPropertyIdToCustomPropertiesAndCustomPropertyValues do
  use Ecto.Migration

  def change do
    alter table(:custom_property_values) do
      add :whippy_custom_property_id, :string
      add :external_custom_property_id, :string
    end

    alter table(:custom_properties) do
      add :whippy_custom_property_id, :string
      add :external_custom_property_id, :string
    end
  end
end
