defmodule Sync.Repo.Migrations.AddWhippyContactIdAndExternalContactIdToContacts do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add(:whippy_contact_id, :string)
      add(:external_contact_id, :string)
      add(:external_organization_entity_type, :string)
      remove(:address)
      add(:address, :map)
    end
  end

  def down do
    alter table(:contacts) do
      remove(:whippy_contact_id)
      remove(:external_contact_id)
      remove(:external_organization_entity_type)
      remove(:address)
      add(:address, :string)
    end
  end
end
