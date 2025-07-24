defmodule Sync.Repo.Migrations.AddErrorsToCustomObjectsAndCustomProperties do
  use Ecto.Migration

  def change do
    alter table(:custom_objects) do
      add :errors, :map, default: %{}
    end

    alter table(:custom_properties) do
      add :errors, :map, default: %{}
    end
  end
end
