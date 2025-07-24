defmodule Sync.Repo.Migrations.AddContactFieldsToActivities do
  use Ecto.Migration

  def up do
    alter table(:activities) do
      add(:whippy_contact_id, :string)
      add(:external_contact_id, :string)
      add(:external_contact_entity_type, :string)
    end
  end

  def down do
    alter table(:acitivities) do
      remove(:whippy_contact_id)
      remove(:external_contact_id)
      remove(:external_contact_entity_type)
    end
  end
end
