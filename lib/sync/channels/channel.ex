defmodule Sync.Channels.Channel do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Integrations.Integration

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          external_channel_id: String.t(),
          whippy_channel_id: Ecto.UUID.t() | nil,
          integration_id: Ecto.UUID.t(),
          timezone: String.t(),
          external_organization_id: String.t(),
          whippy_organization_id: String.t()
        }

  @derive {Jason.Encoder, only: ~w(
    id 
    external_channel_id 
    whippy_channel_id 
    integration_id 
    timezone 
    external_organization_id 
    whippy_organization_id
  )a}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "channels" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :external_channel_id, :string
    field :whippy_channel_id, :string
    field :timezone, :string
    field :whippy_channel, :map, default: %{}
    field :external_channel, :map, default: %{}

    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :external_channel_id,
      :whippy_channel_id,
      :integration_id,
      :external_channel,
      :timezone
    ])
    |> validate_required([
      :external_organization_id,
      :external_channel_id,
      :external_channel,
      :integration_id,
      :whippy_channel_id,
      :whippy_organization_id
    ])
    |> unique_constraint([:integration_id, :external_channel_id, :whippy_channel_id],
      name: :channels_integration_unique_index
    )
  end

  def external_insert_changeset(channel, attrs) do
    time_now = DateTime.utc_now(:second)

    channel
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :external_channel_id,
      :whippy_channel_id,
      :integration_id,
      :external_channel,
      :timezone
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> validate_required([
      :external_organization_id,
      :external_channel_id,
      :external_channel,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :external_channel_id, :whippy_channel_id],
      name: :channels_integration_unique_index
    )
  end

  @doc false
  def whippy_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :external_channel_id,
      :whippy_channel_id,
      :integration_id,
      :timezone
    ])
    |> validate_required([
      :whippy_organization_id,
      :whippy_channel_id,
      :whippy_channel,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :external_channel_id, :whippy_channel_id],
      name: :channels_integration_unique_index
    )
  end

  def external_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :external_channel_id,
      :whippy_channel_id,
      :integration_id,
      :timezone
    ])
    |> validate_required([
      :external_organization_id,
      :external_channel_id,
      :external_channel,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :external_channel_id, :whippy_channel_id],
      name: :channels_integration_unique_index
    )
  end
end
