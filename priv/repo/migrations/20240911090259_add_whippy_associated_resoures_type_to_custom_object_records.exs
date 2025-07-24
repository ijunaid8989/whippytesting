defmodule Sync.Repo.Migrations.AddWhippyAssociatedResouresTypeToCustomObjectRecords do
  use Ecto.Migration

  def change do
    alter table(:custom_object_records) do
      add :whippy_associated_resource_type, :string
    end
  end
end
