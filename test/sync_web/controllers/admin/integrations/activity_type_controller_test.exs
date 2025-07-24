defmodule SyncWeb.Admin.Integrations.ActivityTypeControllerTest do
  @moduledoc false

  use SyncWeb.ConnCase, async: false

  import Mock
  import Sync.Factory

  alias Sync.Authentication
  alias Sync.Fixtures.AvionteClient
  alias Sync.Fixtures.LoxoClient
  alias Sync.Fixtures.TempworksClient

  setup do
    conn = put_req_header(build_conn(), "authorization", "Basic " <> Base.encode64("username:password"))

    avionte_integration =
      insert(:integration,
        integration: "avionte",
        client: :avionte,
        whippy_organization_id: "test_whippy_organization_id",
        authentication: %{
          "external_api_key" => "test_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "scope" => "test_scope",
          "grant_type" => "client_credentials",
          "fallback_external_user_id" => "12245",
          "tenant" => "whippy",
          "whippy_api_key" => "test_whippy_api_key"
        }
      )

    tempworks_integration = insert(:integration, client: :tempworks)

    loxo_integration = insert(:integration, client: :loxo)

    {:ok,
     avionte_integration: avionte_integration,
     tempworks_integration: tempworks_integration,
     loxo_integration: loxo_integration,
     conn: conn}
  end

  describe "index/2" do
    test "returns a list of activity types for an integration with client avionte", %{
      conn: conn,
      avionte_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], avionte_client_mocks()},
        {Authentication.Avionte, [], avionte_authentication_mocks()}
      ]) do
        conn = get(conn, "/api/v1/admin/integrations/#{integration.id}/activity_types")

        assert json_response(conn, 200) == %{
                 "data" => [
                   %{"activity_type_id" => -95, "name" => "Daily SMS Summary"},
                   %{"activity_type_id" => -94, "name" => "Pixel Bot Interview Email"},
                   %{"activity_type_id" => -93, "name" => "Happy Birthday Email"},
                   %{"activity_type_id" => -92, "name" => "How's it Going Email"},
                   %{"activity_type_id" => -91, "name" => "First Day Reminder Email"},
                   %{"activity_type_id" => -90, "name" => "Onboarding Reminder Email"},
                   %{"activity_type_id" => -89, "name" => "Onboarding Assigned Email"},
                   %{"activity_type_id" => -88, "name" => "Application Received Email"}
                 ]
               }
      end
    end

    test "returns a list of activity types for an integration with client twmpworks", %{
      conn: conn,
      tempworks_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], tempworks_client_mocks()},
        {Authentication.Tempworks, [], tempworks_authentication_mocks()}
      ]) do
        conn = get(conn, "/api/v1/admin/integrations/#{integration.id}/activity_types")

        assert json_response(conn, 200) == %{
                 "data" => [
                   %{"activity_type_id" => 1, "name" => "1st Interview w/ client"},
                   %{"activity_type_id" => 2, "name" => "1st Recruiting Call"},
                   %{"activity_type_id" => 3, "name" => "Absence"},
                   %{"activity_type_id" => 4, "name" => "Absent (Sick)"},
                   %{"activity_type_id" => 5, "name" => "Accepted"}
                 ]
               }
      end
    end

    test "returns a list of activity types for an integration with client loxo", %{
      conn: conn,
      loxo_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], loxo_client_mocks()},
        {Authentication.Loxo, [], loxo_authentication_mocks()}
      ]) do
        conn = get(conn, "/api/v1/admin/integrations/#{integration.id}/activity_types")

        assert json_response(conn, 200) == %{
                 "data" => [
                   %{"activity_type_id" => 1_676_385, "name" => "Marked as Maybe"},
                   %{"activity_type_id" => 1_676_386, "name" => "Marked as Yes"},
                   %{"activity_type_id" => 1_676_387, "name" => "Longlisted"},
                   %{"activity_type_id" => 1_676_388, "name" => "Note Update"},
                   %{"activity_type_id" => 1_676_389, "name" => "Sent Automated Email"}
                 ]
               }
      end
    end
  end

  defp avionte_client_mocks do
    [
      get: fn _url, _headers, _opts ->
        AvionteClient.list_talent_activity_types_fixture()
      end
    ]
  end

  defp avionte_authentication_mocks do
    [
      get_api_key: fn _integration ->
        {:ok, "test_api_key"}
      end,
      get_or_regenerate_access_token: fn integration ->
        {:ok, "test_bearer_token", integration}
      end,
      get_tenant: fn _integration ->
        {:ok, "test_tenant"}
      end
    ]
  end

  defp tempworks_client_mocks do
    [
      get: fn _url, _headers, _opts ->
        TempworksClient.list_message_actions_fixture()
      end
    ]
  end

  defp tempworks_authentication_mocks do
    [
      get_or_regenerate_service_token: fn integration ->
        {:ok, integration}
      end
    ]
  end

  defp loxo_client_mocks do
    [
      get: fn _url, _headers ->
        LoxoClient.list_activity_types_fixture()
      end
    ]
  end

  defp loxo_authentication_mocks do
    [
      get_api_key: fn _integration ->
        {:ok, "test_api_key"}
      end,
      get_agency_slug: fn _integration ->
        {:ok, "test_agency_slug"}
      end
    ]
  end
end
