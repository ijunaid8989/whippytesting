defmodule Sync.Repo.Migrations.AddPartialUniqueConstraintToChannelsOnIntegrationIdAndExternalChannelId do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      unique_index(:channels, [:integration_id, :external_channel_id, :whippy_channel_id],
        nulls_distinct: false,
        name: "channels_integration_unique_index"
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(:channels, [:integration_id, :external_channel_id, :whippy_channel_id],
        nulls_distinct: false,
        name: "channels_integration_unique_index"
      )
    )
  end
end
