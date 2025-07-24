defmodule Sync.Repo.Migrations.CreateIndexForCustomPropertyValues do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      unique_index(:custom_property_values, [
        :integration_id,
        :custom_object_record_id,
        :custom_property_id
      ])
    )
  end

  def down do
    drop_if_exists(
      unique_index(:custom_property_values, [
        :integration_id,
        :custom_object_record_id,
        :custom_property_id
      ])
    )
  end
end
