defmodule Sync.Integrations.Clients.Crelate.SettingsEmbed do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @cast_attrs [
    :daily_sync_at,
    :messages_sync_at,
    :sync_at,
    :crelate_messages_action_id,
    :sync_custom_data,
    :send_contacts_to_external_integrations,
    :use_production_url,
    :contacts_offset
  ]

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :daily_sync_at, :string
    field :messages_sync_at, :string
    field :sync_at, :string
    field :crelate_messages_action_id, :string
    field :sync_custom_data, :boolean, default: false
    field :send_contacts_to_external_integrations, :boolean, default: true
    field :use_production_url, :boolean, default: false
    field :contacts_offset, :integer
  end

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_attrs)
    |> Formatter.validate_cron_expression(:sync_at)
    |> Formatter.validate_cron_expression(:daily_sync_at)
    |> Formatter.validate_cron_expression(:messages_sync_at)
  end
end
