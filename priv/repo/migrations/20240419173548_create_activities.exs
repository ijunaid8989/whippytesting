defmodule Sync.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :activity_type, :string
      add :whippy_activity_id, :string
      add :external_activity_id, :string
      add :whippy_activity, :map
      add :external_activity, :map
      add :whippy_user_id, :string
      add :external_user_id, :string
      add :integration_id, references(:integrations, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:activities, [:integration_id])
  end
end
