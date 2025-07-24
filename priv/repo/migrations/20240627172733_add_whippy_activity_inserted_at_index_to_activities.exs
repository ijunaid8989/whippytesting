defmodule Sync.Repo.Migrations.AddWhippyActivityInsertedAtIndexToActivities do
  use Ecto.Migration

  def up do
    create_if_not_exists index(:activities, [:integration_id, :whippy_activity_inserted_at],
                           where: "external_activity_id IS NULL"
                         )
  end

  def down do
    drop_if_exists index(:activities, [:integration_id, :whippy_activity_inserted_at],
                     where: "external_activity_id IS NULL"
                   )
  end
end
