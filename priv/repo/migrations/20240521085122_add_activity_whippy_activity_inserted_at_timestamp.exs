defmodule Sync.Repo.Migrations.AddActivityWhippyActivityInsertedAtTimestamp do
  use Ecto.Migration

  def up do
    alter table(:activities) do
      add(:whippy_activity_inserted_at, :utc_datetime_usec)
    end
  end

  def down do
    alter table(:activities) do
      remove(:whippy_activity_inserted_at)
    end
  end
end
