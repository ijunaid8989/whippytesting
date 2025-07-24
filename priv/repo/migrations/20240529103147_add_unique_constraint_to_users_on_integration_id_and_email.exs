defmodule Sync.Repo.Migrations.AddUniqueConstraintToUsersOnIntegrationIdAndEmail do
  use Ecto.Migration

  def up do
    create_if_not_exists(unique_index(:users, [:integration_id, :email]))
  end

  def down do
    drop_if_exists(unique_index(:users, [:integration_id, :email]))
  end
end
