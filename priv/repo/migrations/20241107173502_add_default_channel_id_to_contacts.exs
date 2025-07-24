defmodule Sync.Repo.Migrations.AddDefaultChannelIdToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :default_channel_id, :integer
    end
  end
end
