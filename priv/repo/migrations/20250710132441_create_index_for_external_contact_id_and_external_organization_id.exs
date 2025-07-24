defmodule Sync.Repo.Migrations.CreateIndexForExternalContactIdAndExternalOrganizationId do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(
        :contacts,
        [
          :external_contact_id,
          :external_organization_id
        ],
        concurrently: true
      )
    )
  end
end
