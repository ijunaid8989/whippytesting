defmodule Sync.Repo.Migrations.AddExternalAndWhippyCustomObjectRecordIdsToCustomObjectRecords do
  use Ecto.Migration

  def change do
    alter table(:custom_object_records) do
      add :external_custom_object_record_id, :string
      add :whippy_custom_object_record_id, :string
    end
  end
end
