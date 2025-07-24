defmodule Sync.Repo.Migrations.CreateIndexForContactsAndCustomObjects do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      index(
        :contacts,
        [
          :integration_id,
          :whippy_organization_id,
          :external_organization_id,
          :whippy_contact_id,
          :external_contact_id
        ],
        where: "whippy_contact_id IS NOT NULL AND external_contact_id IS NOT NULL",
        name: :idx_contacts_optimization
      )
    )

    create_if_not_exists(
      index(
        :custom_object_records,
        [
          :external_custom_object_record_id,
          :integration_id,
          :custom_object_id
        ],
        name: :idx_custom_object_records_optimization
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :contacts,
        [
          :integration_id,
          :whippy_organization_id,
          :external_organization_id,
          :whippy_contact_id,
          :external_contact_id
        ],
        where: "whippy_contact_id IS NOT NULL AND external_contact_id IS NOT NULL",
        name: :idx_contacts_optimization
      )
    )

    drop_if_exists(
      index(
        :custom_object_records,
        [
          :external_custom_object_record_id,
          :integration_id,
          :custom_object_id
        ],
        name: :idx_custom_object_records_optimization
      )
    )
  end
end
