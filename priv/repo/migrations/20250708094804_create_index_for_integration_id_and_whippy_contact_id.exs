defmodule Sync.Repo.Migrations.CreateIndexForIntegrationIdAndWhippyContactId do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(
        :contacts,
        [
          :integration_id,
          :whippy_contact_id
        ],
        concurrently: true
      )
    )
  end
end
