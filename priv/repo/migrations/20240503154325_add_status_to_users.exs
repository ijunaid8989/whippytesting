defmodule Sync.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:completed_at, :timestamp)
    end
  end
end
