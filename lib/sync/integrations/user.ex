defmodule Sync.Integrations.User do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Integrations.Integration
  alias Sync.Utils.Ecto.Changeset.Formatter

  @type t :: %__MODULE__{
          external_organization_id: String.t(),
          whippy_organization_id: String.t(),
          whippy_user_id: String.t(),
          external_user_id: String.t(),
          email: String.t(),
          authentication: Sync.Utils.Ecto.EncryptedMap.t()
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :external_organization_id,
             :whippy_organization_id,
             :whippy_user_id,
             :external_user_id,
             :email,
             :authentication,
             :inserted_at,
             :updated_at
           ]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :whippy_user_id, :string
    field :external_user_id, :string
    field :email, :string
    field :authentication, Sync.Utils.Ecto.EncryptedMap

    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :external_organization_id,
      :whippy_organization_id,
      :whippy_user_id,
      :external_user_id,
      :email,
      :integration_id,
      :authentication
    ])
    |> validate_required([
      :external_organization_id,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :whippy_user_id],
      name: :users_integration_id_whippy_user_id_index
    )
  end

  def external_changeset(user, attrs) do
    time_now = DateTime.utc_now(:second)

    user
    |> cast(attrs, [
      :external_organization_id,
      :external_user_id,
      :email,
      :authentication,
      :integration_id
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> Formatter.downcase(:email)
    |> validate_required([:external_organization_id, :external_user_id])
  end

  def whippy_changeset(user, attrs) do
    time_now = DateTime.utc_now(:second)

    user
    |> cast(attrs, [
      :whippy_organization_id,
      :whippy_user_id,
      :email,
      :authentication,
      :integration_id
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> validate_required([:whippy_organization_id, :whippy_user_id])
    |> unique_constraint([:integration_id, :whippy_user_id],
      name: :users_integration_id_whippy_user_id_index
    )
  end
end
