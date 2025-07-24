defmodule Sync.Repo.Migrations.AddErrorsToCustomObjectRecordsAndCustomPropertyValues do
  use Ecto.Migration

  def change do
    alter table(:custom_object_records) do
      add(:errors, :map, null: false, default: %{})
    end

    alter table(:custom_property_values) do
      add(:errors, :map, null: false, default: %{})
    end
  end
end
