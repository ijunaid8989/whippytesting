defmodule Sync.IntegrationsTest do
  use Sync.DataCase

  import Sync.Factory

  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Integrations.User

  describe "integrations" do
    @invalid_attrs %{
      authentication: nil,
      integration: nil,
      settings: nil,
      external_organization_id: nil,
      whippy_organization_id: nil
    }

    test "list_integrations/0 returns all integrations" do
      whippy_organization_id = Ecto.UUID.generate()
      integration = insert(:integration, whippy_organization_id: whippy_organization_id)
      assert Integrations.list_integrations(whippy_organization_id) == [integration]
    end

    test "get_integration!/1 returns the integration with given id" do
      integration = insert(:integration)
      assert Integrations.get_integration!(integration.id) == integration
    end

    test "create_integration/1 with valid data creates an integration" do
      authentication = %{
        "acr_values" => "tenant:tenant_name pid:tenant_pid",
        "client_id" => "client_id",
        "client_secret" => "client_secret",
        "scope" =>
          "assignment-write contact-write customer-write document-write employee-write hotlist-write message-write offline_access openid ordercandidate-write order-write profile universal-search",
        "whippy_api_key" => "api_key",
        "access_token" => nil,
        "expires_in" => nil,
        "refresh_token" => nil,
        "token_expires_at" => nil,
        "token_type" => "Bearer"
      }

      valid_attrs = %{
        authentication: authentication,
        integration: "some integration",
        client: "tempworks",
        settings: %{},
        external_organization_id: "some external_organization_id",
        whippy_organization_id: "some whippy_organization_id"
      }

      assert {:ok, %Integration{} = integration} = Integrations.create_integration(valid_attrs)
      assert integration.integration == "some integration"

      assert integration.settings == %{
               "daily_sync_at" => nil,
               "default_messages_timezone" => nil,
               "messages_sync_at" => nil,
               "only_active_assignments" => false,
               "send_contacts_to_external_integrations" => true,
               "sync_at" => nil,
               "sync_custom_data" => false,
               "tempworks_messages_action_id" => nil,
               "tempworks_region" => nil,
               "assignment_offset" => nil,
               "employee_details_offset" => nil,
               "advance_employee_offset" => nil,
               "advance_assignment_offset" => nil,
               "monthly_sync_at" => nil,
               "use_advance_search" => true,
               "webhooks" => [],
               "branches_to_sync" => [],
               "contact_details_offset" => nil,
               "job_orders_offset" => nil,
               "customers_offset" => nil,
               "employee_sync_at" => nil
             }

      assert integration.external_organization_id == "some external_organization_id"
      assert integration.whippy_organization_id == "some whippy_organization_id"
      assert integration.authentication == authentication
    end

    test "create_integration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Integrations.create_integration(@invalid_attrs)
    end

    test "update_integration/2 with valid data updates the integration" do
      integration = insert(:integration)

      update_attrs = %{
        integration: "some updated integration",
        client: "tempworks",
        settings: %{},
        external_organization_id: "some updated external_organization_id",
        whippy_organization_id: "some updated whippy_organization_id",
        authentication: %{
          acr_values: "some values",
          client_id: "some client_id",
          client_secret: "some client secret",
          scope: "some scope",
          whippy_api_key: "some api key"
        }
      }

      assert {:ok, %Integration{} = integration} = Integrations.update_integration(integration, update_attrs)

      assert integration.authentication == %{
               "acr_values" => "some values",
               "client_id" => "some client_id",
               "client_secret" => "some client secret",
               "scope" => "some scope",
               "whippy_api_key" => "some api key",
               "access_token" => nil,
               "expires_in" => nil,
               "refresh_token" => nil,
               "token_expires_at" => nil,
               "token_type" => "Bearer"
             }

      assert integration.integration == "some updated integration"

      assert integration.settings == %{
               "daily_sync_at" => nil,
               "default_messages_timezone" => nil,
               "messages_sync_at" => nil,
               "only_active_assignments" => false,
               "send_contacts_to_external_integrations" => true,
               "sync_at" => nil,
               "sync_custom_data" => false,
               "tempworks_messages_action_id" => nil,
               "tempworks_region" => nil,
               "assignment_offset" => nil,
               "employee_details_offset" => nil,
               "advance_employee_offset" => nil,
               "advance_assignment_offset" => nil,
               "monthly_sync_at" => nil,
               "use_advance_search" => true,
               "webhooks" => [],
               "branches_to_sync" => [],
               "contact_details_offset" => nil,
               "job_orders_offset" => nil,
               "customers_offset" => nil,
               "employee_sync_at" => nil
             }

      assert integration.external_organization_id == "some updated external_organization_id"
      assert integration.whippy_organization_id == "some updated whippy_organization_id"
    end

    test "update_integration/2 with invalid data returns error changeset" do
      integration = insert(:integration)

      assert {:error, %Ecto.Changeset{}} = Integrations.update_integration(integration, @invalid_attrs)

      assert integration == Integrations.get_integration!(integration.id)
    end

    test "delete_integration/1 deletes the integration" do
      integration = insert(:integration)
      assert {:ok, %Integration{}} = Integrations.delete_integration(integration)
      assert_raise Ecto.NoResultsError, fn -> Integrations.get_integration!(integration.id) end
    end
  end

  describe "users" do
    @invalid_attrs %{
      integeration: nil,
      external_organization_id: nil,
      whippy_organization_id: nil,
      whippy_user_id: nil,
      external_user_id: nil,
      email: nil,
      external_user_auth: nil
    }

    test "list_users/1 returns all users" do
      whippy_organization_id = Ecto.UUID.generate()
      user = insert(:user, whippy_organization_id: whippy_organization_id)
      assert Integrations.list_users(whippy_organization_id) == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = insert(:user)
      assert Integrations.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      integration = insert(:integration)

      valid_attrs = %{
        integration_id: integration.id,
        external_organization_id: "some external_organization_id",
        whippy_organization_id: "some whippy_organization_id",
        whippy_user_id: "some whippy_user_id",
        external_user_id: "some external_user_id",
        email: "some email",
        external_user_auth: %{}
      }

      assert {:ok, %User{} = user} = Integrations.create_user(valid_attrs)
      assert user.external_organization_id == "some external_organization_id"
      assert user.whippy_organization_id == "some whippy_organization_id"
      assert user.whippy_user_id == "some whippy_user_id"
      assert user.external_user_id == "some external_user_id"
      assert user.email == "some email"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Integrations.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      integration = insert(:integration)
      user = insert(:user, integration: integration)

      update_attrs = %{
        integration_id: integration.id,
        external_organization_id: "some updated external_organization_id",
        whippy_organization_id: "some updated whippy_organization_id",
        whippy_user_id: "some updated whippy_user_id",
        external_user_id: "some updated external_user_id",
        email: "some updated email",
        external_user_auth: %{}
      }

      assert {:ok, %User{} = user} = Integrations.update_user(user, update_attrs)
      assert user.external_organization_id == "some updated external_organization_id"
      assert user.whippy_organization_id == "some updated whippy_organization_id"
      assert user.whippy_user_id == "some updated whippy_user_id"
      assert user.external_user_id == "some updated external_user_id"
      assert user.email == "some updated email"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = insert(:user)
      assert {:error, %Ecto.Changeset{}} = Integrations.update_user(user, @invalid_attrs)
      assert user == Integrations.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = insert(:user)
      assert {:ok, %User{}} = Integrations.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Integrations.get_user!(user.id) end
    end
  end
end
