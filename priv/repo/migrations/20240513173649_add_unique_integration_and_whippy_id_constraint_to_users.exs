defmodule Sync.Repo.Migrations.AddUniqueIntegrationAndWhippyIdConstraintToUsers do
  use Ecto.Migration

  def up do
    create_if_not_exists(unique_index(:users, [:integration_id, :whippy_user_id]))
  end

  def down do
    drop_if_exists(unique_index(:users, [:integration_id, :whippy_user_id]))
  end
end
