defmodule Sync.Repo.Migrations.RemoveAdditionalColumnInUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove(:external_user_auth)
    end
  end
end
