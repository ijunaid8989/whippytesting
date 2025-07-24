defmodule Sync.Integrations.Clients.Aqore.SettingsEmbed do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @required_attrs [:office_id, :office_name]
  @cast_attrs [:daily_sync_at, :sync_custom_data, :messages_sync_at, :send_contacts_to_external_integrations] ++
                @required_attrs

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :daily_sync_at, :string
    field :office_id, :integer
    field :office_name, :string
    field :sync_custom_data, :boolean, default: false
    field :messages_sync_at, :string
    field :send_contacts_to_external_integrations, :boolean, default: false
  end

  @doc false
  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, @cast_attrs)
    |> Formatter.validate_cron_expression(:daily_sync_at)
    |> Formatter.validate_cron_expression(:messages_sync_at)
    |> validate_required(@required_attrs)
  end
end
