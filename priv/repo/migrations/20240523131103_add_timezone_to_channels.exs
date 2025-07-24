defmodule Sync.Repo.Migrations.AddTimezoneToChannels do
  use Ecto.Migration

  def up do
    alter table(:channels) do
      add(:timezone, :string)
    end
  end

  def down do
    alter table(:channels) do
      remove(:timezone)
    end
  end
end
