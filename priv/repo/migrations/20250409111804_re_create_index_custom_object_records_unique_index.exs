defmodule Sync.Repo.Migrations.ReCreateIndexCustomObjectRecordsUniqueIndex do
  use Ecto.Migration

  import Ecto.Query

  alias Sync.Repo

  def up do
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

    # # DELETE duplicate custom property values
    # execute("""
    #  WITH records_to_delete AS (
    # SELECT cor1.id
    # FROM custom_object_records cor1
    # WHERE EXISTS (
    #     SELECT 1
    #     FROM custom_object_records cor2
    #     WHERE cor2.external_custom_object_record_id = cor1.external_custom_object_record_id
    #     AND cor2.custom_object_id = cor1.custom_object_id
    #     GROUP BY cor2.external_custom_object_record_id, cor2.custom_object_id
    #     HAVING COUNT(*) > 1
    # )
    # AND whippy_custom_object_record_id IS NULL
    # )

    # DELETE FROM custom_property_values
    # WHERE custom_object_record_id IN (SELECT id FROM records_to_delete);

    # """)

    # # DELETE duplicate custom object records
    # execute("""
    # WITH records_to_delete AS (
    # SELECT cor1.id
    # FROM custom_object_records cor1
    # WHERE EXISTS (
    #     SELECT 1
    #     FROM custom_object_records cor2
    #     WHERE cor2.external_custom_object_record_id = cor1.external_custom_object_record_id
    #     AND cor2.custom_object_id = cor1.custom_object_id
    #     GROUP BY cor2.external_custom_object_record_id, cor2.custom_object_id
    #     HAVING COUNT(*) > 1
    # )
    # AND whippy_custom_object_record_id IS NULL
    # )

    # DELETE FROM custom_object_records
    # WHERE id IN (SELECT id FROM records_to_delete);
    # """)

    create_if_not_exists(
      unique_index(
        :custom_object_records,
        [
          :integration_id,
          :custom_object_id,
          :external_custom_object_record_id
        ],
        nulls_distinct: false,
        name: :custom_object_records_unique_index
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
          :external_custom_object_record_id
        ],
        nulls_distinct: false,
        name: :custom_object_records_unique_index
      )
    )
  end
end
