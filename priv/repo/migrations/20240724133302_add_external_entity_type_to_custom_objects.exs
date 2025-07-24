defmodule Sync.Repo.Migrations.AddExternalEntityTypeToCustomObjects do
  use Ecto.Migration

  def change do
    alter table(:custom_objects) do
      add :external_entity_type, :string
    end
  end
end
