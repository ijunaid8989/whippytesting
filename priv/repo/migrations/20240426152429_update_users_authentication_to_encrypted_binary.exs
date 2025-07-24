defmodule Sync.Repo.Migrations.UpdateUsersAuthenticationToEncryptedBinary do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :external_user_auth
      add :external_user_auth, :binary
    end
  end

  def down do
    alter table(:users) do
      remove :external_user_auth
      add :external_user_auth, :map
    end
  end
end
