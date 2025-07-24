defmodule Sync.Repo.Migrations.DelDefaultChannelIdAndAddWhippyChannelIdAndExternalChannelId do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      remove :default_channel_id
      add :whippy_channel_id, :string
      add :external_channel_id, :string
    end
  end
end
