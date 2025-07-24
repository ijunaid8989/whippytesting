defmodule Sync.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def change do
    create table(:integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :integration, :string
      add :settings, :map
      add :authentication, :map
      add :external_organization_id, :string
      add :whippy_organization_id, :string

      timestamps(type: :utc_datetime)
    end
  end
end
