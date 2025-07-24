defmodule Sync.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_organization_id, :string
      add :whippy_organization_id, :string
      add :whippy_user_id, :string
      add :external_user_id, :string
      add :email, :string
      add :external_user_auth, :map

      add(
        :integration_id,
        references(:integrations, on_delete: :nothing, type: :binary_id)
      )

      timestamps(type: :utc_datetime)
    end

    create(index(:users, [:integration_id]))
  end
end
