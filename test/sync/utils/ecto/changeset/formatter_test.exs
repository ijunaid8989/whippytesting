defmodule Sync.Utils.Ecto.Changeset.FormatterTest do
  use ExUnit.Case

  alias Sync.Contacts.Contact
  alias Sync.Integrations.Clients.Aqore.IntegrationAuthenticationEmbed
  alias Sync.Integrations.Clients.Avionte.SettingsEmbed
  alias Sync.Integrations.User
  alias Sync.Utils.Ecto.Changeset.Formatter

  describe "downcase/2" do
    test "edits the values found under the given keys to lower case" do
      attrs = %{
        "email" => "Example@Example.com"
      }

      changeset = User.changeset(%User{}, attrs)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 email: "example@example.com"
               }
             } = Formatter.downcase(changeset, [:email])
    end
  end

  describe "to_e164/2" do
    test "formats the phone number in the given key to E.164 format" do
      attrs = %{"phone" => "555-555-5555"}
      changeset = Contact.whippy_insert_changeset(%Contact{}, attrs)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 phone: "+15555555555"
               }
             } = Formatter.to_e164(changeset, :phone)
    end
  end

  describe "validate_cron_expression/2" do
    test "returns valid changeset when cron expression is valid" do
      attrs = %{
        daily_sync_at: "0 0 * * * *",
        sync_at: "41 9 * * *",
        messages_sync_at: "*/5 * * * *"
      }

      changeset =
        Ecto.Changeset.cast(%SettingsEmbed{daily_sync_at: nil}, attrs, [
          :daily_sync_at,
          :sync_at,
          :messages_sync_at
        ])

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{
                 daily_sync_at: "0 0 * * * *"
               }
             } = Formatter.validate_cron_expression(changeset, :daily_sync_at)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{
                 sync_at: "41 9 * * *"
               }
             } = Formatter.validate_cron_expression(changeset, :sync_at)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{
                 messages_sync_at: "*/5 * * * *"
               }
             } = Formatter.validate_cron_expression(changeset, :messages_sync_at)
    end

    test "returns invalid changeset when cron expression is invalid" do
      attrs = %{daily_sync_at: "0 0 * *"}
      changeset = Ecto.Changeset.cast(%SettingsEmbed{daily_sync_at: nil}, attrs, [:daily_sync_at])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 daily_sync_at: {"Invalid cron expression", [validation: :format]}
               ]
             } = Formatter.validate_cron_expression(changeset, :daily_sync_at)
    end
  end

  describe "validate_url/2" do
    test "returns valid changeset when url is valid" do
      attrs = %{base_api_url: "https://bircchapi.zenople.com"}

      changeset =
        Ecto.Changeset.cast(%IntegrationAuthenticationEmbed{base_api_url: nil}, attrs, [
          :base_api_url
        ])

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{
                 base_api_url: "https://bircchapi.zenople.com"
               }
             } = Formatter.validate_url(changeset, :base_api_url)
    end

    test "returns invalid changeset when cron expression is invalid" do
      attrs = %{base_api_url: "https://bircchapi."}

      changeset =
        Ecto.Changeset.cast(%IntegrationAuthenticationEmbed{base_api_url: nil}, attrs, [
          :base_api_url
        ])

      assert %Ecto.Changeset{
               action: nil,
               changes: %{base_api_url: "https://bircchapi."},
               errors: [base_api_url: {"is not supported", []}],
               valid?: false
             } = Formatter.validate_url(changeset, :base_api_url)
    end
  end
end
