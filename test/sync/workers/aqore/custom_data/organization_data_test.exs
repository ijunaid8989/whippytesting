defmodule Sync.Workers.Aqore.CustomData.OrganizationDataTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory
  import Sync.Fixtures.AqoreClient

  alias Sync.Authentication
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.Aqore.CustomData.AqoreOrganizationData
  alias Sync.Workers.CustomData.Converter

  setup do
    integration =
      insert(:integration,
        integration: "aqore",
        client: :aqore,
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "external_api_key" => "test_aqore_api_key",
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "access_token" => "existing_valid_token"
        }
      )

    custom_object =
      insert(:custom_object,
        integration: integration,
        external_entity_type: "organization_data",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end

  describe "process/1 for process_organization_data_as_custom_object_records" do
    test "logs an error when the organization data custom object is not yet synced to whippy" do
      integration = insert(:integration)

      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "organization_data",
        whippy_organization_id: integration.whippy_organization_id
      )

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreOrganizationData, %{
                          "type" => "process_organization_data_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "aqore organization data custom_object not synced to whippy."
    end

    test "logs an error when the organization_data custom object is not found" do
      integration = insert(:integration)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreOrganizationData, %{
                          "type" => "process_organization_data_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No custom object found for aqore organization data."
    end

    test "finds the organization data custom object and calls the converter with it", %{
      integration: integration,
      custom_object: custom_object
    } do
      with_mocks([
        {HTTPoison, [], http_poison_mocks()},
        {Authentication.Aqore, [],
         get_integration_details: fn aqore_integration ->
           assert aqore_integration.id == integration.id
           {:ok, %{"base_api_url" => "aqore.com", "access_token" => "some_random_token"}}
         end},
        {Converter, [],
         convert_external_resource_to_custom_object_record: fn parser_module, _integration, found_custom_object, _ ->
           assert parser_module == Sync.Clients.Aqore.Parser
           assert custom_object.id == found_custom_object.id
           {:ok, %CustomObjectRecord{}}
         end}
      ]) do
        assert :ok ==
                 perform_job(AqoreOrganizationData, %{
                   "type" => "process_organization_data_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(
          Converter.convert_external_resource_to_custom_object_record(:_, :_, :_, :_),
          1
        )
      end
    end

    test "logs an error when the latest organization data custom object is not yet synced to whippy" do
      integration = insert(:integration)

      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "organization_data",
        whippy_organization_id: integration.whippy_organization_id
      )

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreOrganizationData, %{
                          "type" => "process_daily_organization_data_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "Daily sync. Aqore organization data custom_object not synced to whippy."
    end

    test "logs an error when the latest organization_data custom object is not found" do
      integration = insert(:integration)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreOrganizationData, %{
                          "type" => "process_daily_organization_data_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "Daily sync. No custom object found for aqore organization data."
    end

    test "finds the latest organization data custom object and calls the converter with it", %{
      integration: integration,
      custom_object: custom_object
    } do
      with_mocks([
        {HTTPoison, [], http_poison_mocks()},
        {Authentication.Aqore, [],
         get_integration_details: fn aqore_integration ->
           assert aqore_integration.id == integration.id
           {:ok, %{"base_api_url" => "aqore.com", "access_token" => "some_random_token"}}
         end},
        {Converter, [],
         convert_external_resource_to_custom_object_record: fn parser_module, _integration, found_custom_object, _ ->
           assert parser_module == Sync.Clients.Aqore.Parser
           assert custom_object.id == found_custom_object.id
           {:ok, %CustomObjectRecord{}}
         end}
      ]) do
        assert :ok ==
                 perform_job(AqoreOrganizationData, %{
                   "type" => "process_daily_organization_data_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(
          Converter.convert_external_resource_to_custom_object_record(:_, :_, :_, :_),
          1
        )
      end
    end

    test "pulls organization data from Aqore second time in daily sync when the response is an 15mins interval message",
         %{
           integration: integration
         } do
      with_mocks([
        {HTTPoison, [], http_poison_mocks(:aqore_pull_error)},
        {Authentication.Aqore, [],
         get_integration_details: fn aqore_integration ->
           assert aqore_integration.id == integration.id
           {:ok, %{"base_api_url" => "aqore.com", "access_token" => "some_random_token"}}
         end}
      ]) do
        assert :ok ==
                 perform_job(AqoreOrganizationData, %{
                   "type" => "process_daily_organization_data_as_custom_object_records",
                   "integration_id" => integration.id
                 })
      end
    end
  end

  defp http_poison_mocks do
    [
      post: fn _url, _headers, _opts, _ -> list_organization_data_fixture() end
    ]
  end

  defp http_poison_mocks(:aqore_pull_error) do
    [
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.message_error_fixture()
      end
    ]
  end
end
