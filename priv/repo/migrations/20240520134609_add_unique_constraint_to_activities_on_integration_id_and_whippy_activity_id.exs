defmodule Sync.Repo.Migrations.AddUniqueConstraintToActivitiesOnIntegrationIdAndWhippyActivityId do
  use Ecto.Migration

  def up do
    create_if_not_exists(unique_index(:activities, [:integration_id, :whippy_activity_id]))
  end

  def down do
    drop_if_exists(unique_index(:activities, [:integration_id, :whippy_activity_id]))
  end
end
