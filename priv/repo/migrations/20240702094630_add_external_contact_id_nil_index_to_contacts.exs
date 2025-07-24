defmodule Sync.Repo.Migrations.AddExternalContactIdNilIndexToContacts do
  use Ecto.Migration

  def up do
    create_if_not_exists index(:contacts, [:integration_id],
                           where: "external_contact_id IS NULL",
                           name: "contacts_integration_id_external_contact_id_nil_index"
                         )
  end

  def down do
    drop_if_exists index(:contacts, [:integration_id],
                     where: "external_contact_id IS NULL",
                     name: "contacts_integration_id_external_contact_id_nil_index"
                   )
  end
end
