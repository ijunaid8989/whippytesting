defmodule Sync.Repo.Migrations.AddExternalCustomObjectRecordHashAndShouldSyncToWhippyFields do
  use Ecto.Migration

  def up do
    alter table(:custom_object_records) do
      add :external_custom_object_record_hash, :string
      add :should_sync_to_whippy, :boolean, default: false
    end
  end

  def down do
    alter table(:custom_object_records) do
      remove :external_custom_object_record_hash
      remove :should_sync_to_whippy
    end
  end
end
