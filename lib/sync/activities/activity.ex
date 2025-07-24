defmodule Sync.Activities.Activity do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Integrations.Integration

  @type t ::
          %__MODULE__{
            external_organization_id: String.t(),
            whippy_organization_id: String.t(),
            activity_type: String.t(),
            whippy_activity_id: String.t(),
            external_activity_id: String.t(),
            whippy_activity: :map,
            external_activity: :map,
            whippy_user_id: String.t(),
            external_user_id: String.t(),
            whippy_contact_id: String.t(),
            external_contact_id: String.t(),
            external_contact_entity_type: String.t(),
            whippy_activity_inserted_at: DateTime.t(),
            whippy_conversation_id: String.t(),
            errors: map()
          }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activities" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :activity_type, :string
    field :whippy_activity_id, :string
    field :external_activity_id, :string
    field :whippy_activity, :map
    field :external_activity, :map
    field :whippy_user_id, :string
    field :external_user_id, :string
    field :whippy_contact_id, :string
    field :external_contact_id, :string
    field :external_contact_entity_type, :string
    field :whippy_activity_inserted_at, :utc_datetime_usec
    field :whippy_conversation_id, :string
    field :errors, :map, default: %{}

    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def insert_changeset(activity, attrs) do
    time_now = DateTime.utc_now(:second)

    activity
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :activity_type,
      :whippy_activity_id,
      :external_activity_id,
      :whippy_activity,
      :external_activity,
      :whippy_user_id,
      :external_user_id,
      :integration_id,
      :whippy_contact_id,
      :external_contact_id,
      :external_contact_entity_type,
      :whippy_activity_inserted_at,
      :whippy_conversation_id
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> validate_required([
      :external_organization_id,
      :whippy_organization_id,
      :activity_type,
      :integration_id,
      :whippy_activity_id,
      :whippy_conversation_id
    ])
    |> unique_constraint([:integration_id, :whippy_activity_id],
      name: :activities_integration_id_whippy_activity_id_index
    )
  end

  def update_changeset(activity, attrs) do
    activity
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :activity_type,
      :whippy_activity_id,
      :external_activity_id,
      :whippy_activity,
      :external_activity,
      :whippy_user_id,
      :external_user_id,
      :integration_id,
      :whippy_contact_id,
      :external_contact_id,
      :external_contact_entity_type,
      :whippy_conversation_id
    ])
    |> validate_required([
      :external_organization_id,
      :whippy_organization_id,
      :activity_type,
      :integration_id,
      :whippy_activity_id,
      :whippy_conversation_id
    ])
    |> unique_constraint([:integration_id, :whippy_activity_id],
      name: :activities_integration_id_whippy_activity_id_index
    )
  end

  def error_changeset(activity, attrs) do
    cast(activity, attrs, [:errors])
  end
end
