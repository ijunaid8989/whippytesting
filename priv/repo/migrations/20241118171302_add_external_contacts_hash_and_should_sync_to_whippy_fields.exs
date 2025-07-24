defmodule Sync.Repo.Migrations.AddExternalContactsHashAndShouldSyncToWhippyFields do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add :external_contact_hash, :string
      add :should_sync_to_whippy, :boolean, default: true
    end
  end

  def down do
    alter table(:contacts) do
      remove :external_contact_hash
      remove :should_sync_to_whippy
    end
  end
end
