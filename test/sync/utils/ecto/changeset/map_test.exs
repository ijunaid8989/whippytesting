defmodule Sync.Utils.Ecto.Changeset.MapTest do
  use ExUnit.Case

  alias Sync.Integrations.Clients.Avionte.SettingsEmbed
  alias Sync.Integrations.Integration
  alias Sync.Utils.Ecto.Changeset.Map

  describe "cast/3" do
    test "casts map to changeset when map is valid according to custom validator" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "* * * * *"}}, [
          :client,
          :settings
        ])

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 client: :avionte,
                 settings: %{"daily_sync_at" => "* * * * *"}
               }
             } = Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
    end

    test "casts default values to changeset" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{sync_custom_data: false}}, [
          :client,
          :settings
        ])

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 client: :avionte,
                 settings: %{"sync_custom_data" => false}
               }
             } = Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
    end

    test "adds error to changeset when map is invalid according to custom validator" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "* * * *"}}, [
          :client,
          :settings
        ])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 settings: {"daily_sync_at: Invalid cron expression", []}
               ]
             } = Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
    end

    test "adds error to changeset when opts indicate that the field is required but it is missing" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte}, [
          :client,
          :settings
        ])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 settings: {"can't be blank", []}
               ]
             } = Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1, required: true)
    end

    test "defaults to required being false when not provided in opts" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte}, [
          :client,
          :settings
        ])

      assert %Ecto.Changeset{
               action: nil,
               valid?: true
             } = Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
    end

    test "raises an error when 'with' key is missing in opts" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "* * * * *"}}, [
          :client,
          :settings
        ])

      assert_raise ArgumentError, "Missing required key :with in opts", fn ->
        Map.cast(changeset, :settings, required: true)
      end
    end

    test "raises an error when the value under 'with' is not a function" do
      changeset =
        Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "* * * * *"}}, [
          :client,
          :settings
        ])

      assert_raise ArgumentError, "The value under :with must be a function", fn ->
        Map.cast(changeset, :settings, with: "not a function")
      end
    end
  end
end
