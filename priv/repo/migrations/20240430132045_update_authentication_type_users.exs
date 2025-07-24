defmodule Sync.Repo.Migrations.UpdateAuthenticationTypeUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :authentication
      add :authentication, :binary
    end
  end

  def down do
    alter table(:users) do
      remove :authentication
      add :authentication, :map
    end
  end
end
