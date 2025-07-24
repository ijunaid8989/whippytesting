defmodule Sync.Repo.Migrations.UpdateIntegrationsAuthenticationToEncryptedBinary do
  use Ecto.Migration

  def up do
    alter table(:integrations) do
      remove :authentication
      add :authentication, :binary
    end
  end

  def down do
    alter table(:integrations) do
      remove :authentication
      add :authentication, :map
    end
  end
end
