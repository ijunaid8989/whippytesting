defmodule Sync.Repo.Migrations.AddLookedUpAtToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :looked_up_at, :utc_datetime
    end
  end
end
