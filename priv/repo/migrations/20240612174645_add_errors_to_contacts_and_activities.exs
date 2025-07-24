defmodule Sync.Repo.Migrations.AddErrorsToContactsAndActivities do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add(:errors, :map, null: false, default: %{})
    end

    alter table(:activities) do
      add(:errors, :map, null: false, default: %{})
    end
  end
end
