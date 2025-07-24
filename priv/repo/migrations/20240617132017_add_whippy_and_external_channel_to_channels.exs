defmodule Sync.Repo.Migrations.AddWhippyAndExternalChannelToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add(:whippy_channel, :map, null: false, default: %{})
      add(:external_channel, :map, null: false, default: %{})
    end
  end
end
