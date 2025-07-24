defmodule Sync.Contacts.ActivityContact do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Activities.Activity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activities_contacts" do
    field :whippy_contact_id, :string
    field :external_contact_id, :string
    field :external_contact_type, :string

    belongs_to :activity, Activity, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def insert_changeset(activity_contact, attrs) do
    time_now = DateTime.utc_now(:second)

    activity_contact
    |> cast(attrs, [:whippy_contact_id, :external_contact_id, :external_contact_type, :activity_id])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> validate_required([:whippy_contact_id, :activity_id])
    |> unique_constraint([:activity_id, :whippy_contact_id, :external_contact_id],
      name: :activities_contacts_activity_id_external_contact_id_whippy_cont
    )
  end
end
