defmodule Sync.Repo.Migrations.AddClientToIntegrations do
  use Ecto.Migration

  def up do
    alter table(:integrations) do
      add(:client, :string)
    end
  end

  def down do
    alter table(:integrations) do
      remove(:client)
    end
  end
end
