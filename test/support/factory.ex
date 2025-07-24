defmodule Sync.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Sync.Repo

  alias Sync.Activities
  alias Sync.Channels
  alias Sync.Contacts
  alias Sync.Integrations

  @doc """
  Generates a random valid US phone number in E.164 format.

  US phone numbers follow the pattern: +1 NXX NXX XXXX
  Where:
  - N = 2-9 (area code and exchange code cannot start with 0 or 1)
  - X = 0-9 (any digit)

  Returns a string like "+15551234567"
  """
  def random_us_phone_number do
    # Generate area code (NXX where N = 2-9, X = 0-9)
    area_code = "#{:rand.uniform(8) + 1}#{:rand.uniform(10) - 1}#{:rand.uniform(10) - 1}"

    # Generate exchange code (NXX where N = 2-9, X = 0-9)
    exchange_code = "#{:rand.uniform(8) + 1}#{:rand.uniform(10) - 1}#{:rand.uniform(10) - 1}"

    # Generate subscriber number (XXXX where X = 0-9)
    subscriber_number = "#{:rand.uniform(10) - 1}#{:rand.uniform(10) - 1}#{:rand.uniform(10) - 1}#{:rand.uniform(10) - 1}"

    "+1#{area_code}#{exchange_code}#{subscriber_number}"
  end

  def user_factory do
    %Integrations.User{
      whippy_user_id: "1"
    }
  end

  def integration_factory do
    %Integrations.Integration{
      client: :tempworks,
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      authentication: %{
        "client_id" => "test_client_id",
        "client_secret" => "client_secret",
        "token_expires_at" => "2021-01-01T00:00:00Z",
        "access_token" => "access_token"
      },
      settings: %{}
    }
  end

  def contact_factory do
    %Contacts.Contact{
      email: "some email",
      name: "some name",
      phone: "some phone",
      address: %{},
      birth_date: "",
      preferred_language: "some preferred_language",
      whippy_user_id: "1",
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      whippy_contact: %{},
      external_contact: %{}
    }
  end

  def activity_factory do
    %Activities.Activity{
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      activity_type: "some activity_type",
      whippy_activity_id: Ecto.UUID.generate(),
      external_activity_id: Ecto.UUID.generate(),
      whippy_activity: %{},
      external_activity: %{},
      whippy_user_id: "1"
    }
  end

  def activity_contact_factory do
    %Contacts.ActivityContact{
      external_contact_id: Ecto.UUID.generate(),
      external_contact_type: "some external_contact_type",
      whippy_contact_id: Ecto.UUID.generate()
    }
  end

  def channel_factory do
    %Channels.Channel{
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      external_channel_id: Ecto.UUID.generate(),
      whippy_channel_id: Ecto.UUID.generate(),
      integration: build(:integration)
    }
  end

  def custom_object_factory do
    %Contacts.CustomObject{
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      external_custom_object_id: Ecto.UUID.generate(),
      whippy_custom_object_id: Ecto.UUID.generate(),
      integration: build(:integration),
      whippy_custom_object: %{},
      external_custom_object: %{},
      custom_object_mapping: %{}
    }
  end

  def custom_property_factory do
    %Contacts.CustomProperty{
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      whippy_custom_property_id: Ecto.UUID.generate(),
      whippy_custom_property: %{},
      external_custom_property: %{},
      whippy_custom_object_id: Ecto.UUID.generate(),
      external_custom_object_id: Ecto.UUID.generate()
    }
  end

  def custom_property_value_factory do
    %Contacts.CustomPropertyValue{
      external_organization_id: Ecto.UUID.generate(),
      whippy_organization_id: Ecto.UUID.generate(),
      external_custom_property_value_id: Ecto.UUID.generate(),
      whippy_custom_property_value_id: Ecto.UUID.generate(),
      whippy_custom_property_id: Ecto.UUID.generate(),
      whippy_custom_object_record_id: Ecto.UUID.generate(),
      external_custom_object_record_id: Ecto.UUID.generate(),
      external_custom_property_value: %{},
      whippy_custom_property_value: %{},
      custom_property: build(:custom_property)
    }
  end

  def custom_object_record_factory do
    %Contacts.CustomObjectRecord{
      whippy_organization_id: Ecto.UUID.generate(),
      external_organization_id: Ecto.UUID.generate(),
      whippy_custom_object_id: Ecto.UUID.generate(),
      external_custom_object_id: Ecto.UUID.generate(),
      whippy_custom_object_record: %{},
      external_custom_object_record: %{},
      whippy_associated_resource_id: Ecto.UUID.generate(),
      external_associated_resource_id: Ecto.UUID.generate(),
      whippy_custom_object_record_id: Ecto.UUID.generate(),
      external_custom_object_record_id: Ecto.UUID.generate()
    }
  end
end
