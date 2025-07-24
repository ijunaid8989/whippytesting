defmodule Sync.Integrations.Clients.Hubspot.SettingsEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @cast_attrs [
    :daily_sync_at,
    :contact_cursor,
    :push_contacts_to_hubspot,
    :subscribe_to_webhooks,
    :channels
  ]

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :daily_sync_at, :string
    field :contact_cursor, :string
    field :push_contacts_to_hubspot, :boolean, default: false
    field :subscribe_to_webhooks, :boolean, default: true
    field :channels, {:array, :string}
  end

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_attrs)
    |> Formatter.validate_cron_expression(:daily_sync_at)
  end
end
