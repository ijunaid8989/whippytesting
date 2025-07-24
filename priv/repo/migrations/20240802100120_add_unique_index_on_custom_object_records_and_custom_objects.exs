defmodule Sync.Repo.Migrations.AddUniqueIndexOnCustomObjectRecordsAndCustomObjects do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      unique_index(
        :custom_object_records,
        [
          :integration_id,
          :custom_object_id,
          :external_custom_object_record_id,
          :whippy_custom_object_record_id
        ],
        nulls_distinct: false,
        name: :custom_object_records_unique_index
      )
    )

    create_if_not_exists(
      unique_index(
        :custom_objects,
        [
          :integration_id,
          :external_custom_object_id,
          :whippy_custom_object_id
        ],
        name: :custom_objects_unique_index
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(
        :custom_object_records,
        [
          :integration_id,
          :custom_object_id,
          :external_custom_object_record_id,
          :whippy_custom_object_record_id
        ],
        nulls_distinct: false,
        name: :custom_object_records_unique_index
      )
    )

    drop_if_exists(
      unique_index(
        :custom_objects,
        [
          :integration_id,
          :external_custom_object_id,
          :whippy_custom_object_id
        ],
        name: :custom_objects_unique_index
      )
    )
  end
end
