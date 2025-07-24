defmodule Sync.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :whippy_user_id, :string
      add :name, :string
      add :email, :string
      add :phone, :string
      add :address, :string
      add :birth_date, :string
      add :preferred_langauge, :string
      add :whippy_contact, :map
      add :external_contact, :map
      add :integration_id, references(:integrations, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:integration_id])
  end
end
