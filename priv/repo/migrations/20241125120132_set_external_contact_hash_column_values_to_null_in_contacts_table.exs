defmodule Sync.Repo.Migrations.SetExternalContactHashColumnValuesToNullInContactsTable do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE contacts
    SET external_contact_hash = NULL
    """)
  end
end
