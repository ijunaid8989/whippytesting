defmodule Sync.Contacts.Contact do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Integrations.Integration
  alias Sync.Utils.Ecto.Changeset.Formatter
  alias Sync.Utils.PhoneNumber

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          external_contact_id: String.t(),
          whippy_contact_id: String.t(),
          whippy_user_id: String.t(),
          integration_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          name: String.t(),
          email: String.t(),
          phone: String.t(),
          birth_date: String.t(),
          preferred_language: String.t(),
          address: map(),
          integration: Integration.t(),
          external_contact: map(),
          whippy_contact: map(),
          external_organization_id: String.t(),
          external_organization_entity_type: String.t(),
          whippy_organization_id: String.t(),
          errors: map(),
          should_sync_to_whippy: boolean(),
          external_contact_hash: String.t(),
          whippy_channel_id: String.t(),
          external_channel_id: String.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contacts" do
    field :name, :string
    field :address, :map
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :external_contact_id, :string
    field :external_organization_entity_type, :string
    field :whippy_contact_id, :string
    field :whippy_user_id, :string
    field :email, :string
    field :phone, :string
    field :birth_date, :string
    field :preferred_language, :string
    field :whippy_contact, :map
    field :external_contact, :map
    field :errors, :map, default: %{}
    field :should_sync_to_whippy, :boolean, default: true
    field :external_contact_hash, :string
    field :looked_up_at, :utc_datetime
    field :whippy_channel_id, :string
    field :external_channel_id, :string

    belongs_to :integration, Integration, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def external_insert_changeset(contact, attrs) do
    time_now = DateTime.utc_now(:second)

    contact
    |> cast(attrs, [
      :external_organization_id,
      :external_contact_id,
      :external_organization_entity_type,
      :name,
      :email,
      :phone,
      :address,
      :birth_date,
      :preferred_language,
      :external_contact,
      :integration_id,
      :whippy_channel_id,
      :external_channel_id,
      :should_sync_to_whippy,
      :external_contact_hash,
      :whippy_organization_id
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> Formatter.downcase(:email)
    |> Formatter.to_e164(:phone)
    |> PhoneNumber.validate()
    |> validate_required([
      :external_organization_id,
      :external_contact_id,
      :phone,
      :external_contact,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :phone],
      name: :contacts_integration_id_phone_index
    )
  end

  def external_update_changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :external_organization_id,
      :external_contact_id,
      :external_organization_entity_type,
      :name,
      :email,
      :phone,
      :address,
      :birth_date,
      :preferred_language,
      :external_contact,
      :integration_id,
      :whippy_channel_id,
      :external_channel_id,
      :should_sync_to_whippy,
      :external_contact_hash,
      :looked_up_at
    ])
    |> Formatter.downcase(:email)
    |> Formatter.to_e164(:phone)
    |> PhoneNumber.validate()
    |> validate_required([
      :external_organization_id,
      :external_contact_id,
      :phone,
      :external_contact,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :phone],
      name: :contacts_integration_id_phone_index
    )
  end

  def whippy_insert_changeset(contact, attrs) do
    time_now = DateTime.utc_now(:second)

    contact
    |> cast(attrs, [
      :whippy_organization_id,
      :whippy_contact_id,
      :whippy_user_id,
      :name,
      :email,
      :phone,
      :address,
      :birth_date,
      :preferred_language,
      :whippy_contact,
      :integration_id,
      :whippy_channel_id,
      :external_channel_id
    ])
    |> put_change(:inserted_at, time_now)
    |> put_change(:updated_at, time_now)
    |> validate_required([
      :whippy_organization_id,
      :whippy_contact_id,
      :phone,
      :whippy_contact,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :phone],
      name: :contacts_integration_id_phone_index
    )
  end

  def whippy_update_changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :whippy_organization_id,
      :whippy_contact_id,
      :whippy_user_id,
      :name,
      :email,
      :phone,
      :address,
      :birth_date,
      :preferred_language,
      :whippy_contact,
      :integration_id,
      :whippy_channel_id,
      :external_channel_id,
      :should_sync_to_whippy,
      :looked_up_at
    ])
    |> validate_required([
      :whippy_organization_id,
      :whippy_contact_id,
      :phone,
      :whippy_contact,
      :integration_id
    ])
    |> unique_constraint([:integration_id, :phone],
      name: :contacts_integration_id_phone_index
    )
  end

  def error_changeset(contact, attrs) do
    cast(contact, attrs, [:errors, :should_sync_to_whippy])
  end
end
