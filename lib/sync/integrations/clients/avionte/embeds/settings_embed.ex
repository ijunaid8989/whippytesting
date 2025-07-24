defmodule Sync.Integrations.Clients.Avionte.SettingsEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @cast_attrs [
    :daily_sync_at,
    :messages_sync_at,
    :sync_at,
    :timezone,
    :type_id,
    :talent_requirements,
    :sync_custom_data,
    :send_contacts_to_external_integrations,
    :branches_mapping,
    :contact_type_id,
    :allow_advanced_custom_data
  ]

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :daily_sync_at, :string
    field :messages_sync_at, :string
    field :sync_at, :string
    field :timezone, :string
    field :type_id, :integer
    field :talent_requirements, :map
    field :sync_custom_data, :boolean, default: false
    field :send_contacts_to_external_integrations, :boolean, default: true
    field :branches_mapping, {:array, :map}
    field :contact_type_id, :integer
    field :allow_advanced_custom_data, :boolean, default: false
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
