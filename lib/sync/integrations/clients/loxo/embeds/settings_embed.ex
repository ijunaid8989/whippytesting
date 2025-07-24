defmodule Sync.Integrations.Clients.Loxo.SettingsEmbed do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @required_attrs [:email_type_id, :phone_type_id, :activity_type_id]
  @cast_attrs [:daily_sync_at, :sync_at] ++ @required_attrs

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:daily_sync_at, :string)
    field(:email_type_id, :string)
    field(:phone_type_id, :string)
    field(:activity_type_id, :string)
    field(:sync_at, :string)
  end

  @doc false
  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, @cast_attrs)
    |> Formatter.validate_cron_expression(:sync_at)
    |> Formatter.validate_cron_expression(:daily_sync_at)
    |> validate_required(@required_attrs)
  end
end
