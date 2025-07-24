defmodule Sync.Integrations.Clients.Tempworks.SettingsEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @cast_attrs [
    :daily_sync_at,
    :messages_sync_at,
    :sync_at,
    :default_messages_timezone,
    :tempworks_messages_action_id,
    :tempworks_region,
    :sync_custom_data,
    :only_active_assignments,
    :send_contacts_to_external_integrations,
    :employee_details_offset,
    :advance_employee_offset,
    :advance_assignment_offset,
    :assignment_offset,
    :monthly_sync_at,
    :use_advance_search,
    :webhooks,
    :branches_to_sync,
    :contact_details_offset,
    :job_orders_offset,
    :customers_offset,
    :employee_sync_at
  ]

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :daily_sync_at, :string
    field :messages_sync_at, :string
    field :sync_at, :string
    field :default_messages_timezone, :string
    field :tempworks_messages_action_id, :integer
    field :tempworks_region, :string
    field :sync_custom_data, :boolean, default: false
    field :only_active_assignments, :boolean, default: false
    field :send_contacts_to_external_integrations, :boolean, default: true
    field :employee_details_offset, :integer
    field :advance_employee_offset, :integer
    field :advance_assignment_offset, :integer
    field :assignment_offset, :integer
    field :monthly_sync_at, :string
    field :use_advance_search, :boolean, default: true
    field :webhooks, {:array, :map}, default: []
    field :branches_to_sync, {:array, :integer}, default: []
    field :contact_details_offset, :integer
    field :job_orders_offset, :integer
    field :customers_offset, :integer
    field :employee_sync_at, :string
  end

  # TODO: validate tempworks region is ISO 3166-2 code (e.g. NY, CA, etc.)
  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_attrs)
    |> Formatter.validate_cron_expression(:daily_sync_at)
    |> Formatter.validate_cron_expression(:messages_sync_at)
    |> Formatter.validate_cron_expression(:sync_at)
    |> Formatter.validate_cron_expression(:monthly_sync_at)
    |> Formatter.validate_cron_expression(:employee_sync_at)
  end
end
