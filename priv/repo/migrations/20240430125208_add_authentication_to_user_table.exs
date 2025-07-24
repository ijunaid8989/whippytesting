defmodule Sync.Repo.Migrations.AddAuthenticationToUserTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :authentication, :map
    end
  end
end
