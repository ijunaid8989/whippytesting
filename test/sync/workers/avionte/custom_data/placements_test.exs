defmodule Sync.Workers.Avionte.CustomData.PlacementsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory
  import Sync.Fixtures.AvionteClient

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.Avionte.CustomData.Placements
  alias Sync.Workers.CustomData.Converter

  setup do
    integration =
      insert(:integration,
        integration: "avionte",
        client: :avionte,
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "external_api_key" => "test_avionte_api_key",
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "scope" => "test_scope",
          "grant_type" => "client_credentials",
          "access_token" => "existing_valid_token",
          "token_expires_in" => DateTime.to_unix(DateTime.utc_now()) + 600,
          "tenant" => "apitest",
          "fallback_external_user_id" => "12245"
        }
      )

    custom_object =
      insert(:custom_object,
        integration: integration,
        external_entity_type: "placements",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end

  describe "process/1 for process_placements_as_custom_object_records" do
    test "finds the placements custom object, pulls placements and calls the converter for each of them",
         %{
           integration: integration
         } do
      with_mocks([
        {Converter, [],
         convert_external_resource_to_custom_object_record: fn parser_module, _integration, _found_custom_object, _, _ ->
           assert parser_module == Sync.Clients.Avionte.Parser
           {:ok, %CustomObjectRecord{}}
         end},
        {HTTPoison, [],
         [
           get: fn url, _headers, _opts ->
             cond do
               url =~ "placements/ids" -> list_placements_ids_fixture()
             end
           end
         ]},
        {
          HTTPoison,
          [],
          [
            post: fn url, _headers, _opts, _body ->
              cond do
                url =~ "/placements/multi-query" -> list_placements_fixture()
              end
            end
          ]
        }
      ]) do
        assert :ok ==
                 perform_job(Placements, %{
                   "type" => "process_placements_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(Converter.convert_external_resource_to_custom_object_record(:_, :_, :_, :_, :_), 1)
      end
    end

    test "logs an error when the talent custom object is not found" do
      integration = insert(:integration)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(Placements, %{
                          "type" => "process_placements_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No custom object found for placements."
    end

    test "logs an error when the talent custom object is not yet synced to whippy" do
      integration = insert(:integration)

      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "placements",
        whippy_organization_id: integration.whippy_organization_id
      )

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(Placements, %{
                          "type" => "process_placements_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "placements custom_object not synced to whippy."
    end
  end
end
