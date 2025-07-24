defmodule Sync.Repo.Migrations.AddContactsUniqueConstraintOnIntegrationAndPhone do
  use Ecto.Migration

  def up do
    create_if_not_exists(unique_index(:contacts, [:integration_id, :phone]))
  end

  def down do
    drop_if_exists(unique_index(:contacts, [:integration_id, :phone]))
  end
end
