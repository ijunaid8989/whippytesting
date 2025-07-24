defmodule Sync.Repo.Migrations.AddExternalCustomPropertyHashAndShouldSyncToWhippyFields do
  use Ecto.Migration

  def up do
    alter table(:custom_properties) do
      add :external_custom_property_hash, :string
      add :should_sync_to_whippy, :boolean, default: false
    end
  end

  def down do
    alter table(:custom_properties) do
      remove :external_custom_property_hash
      remove :should_sync_to_whippy
    end
  end
end
