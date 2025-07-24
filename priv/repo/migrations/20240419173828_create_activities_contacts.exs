defmodule Sync.Repo.Migrations.CreateActivitiesContacts do
  use Ecto.Migration

  def change do
    create table(:activities_contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :whippy_contact_id, :string
      add :external_contact_id, :string
      add :external_contact_type, :string
      add :activity_id, references(:activities, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:activities_contacts, [:activity_id])
  end
end
