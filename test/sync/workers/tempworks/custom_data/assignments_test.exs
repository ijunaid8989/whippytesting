defmodule Sync.Workers.Tempworks.CustomData.AssignmentsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory
  import Sync.Fixtures.TempworksClient

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Tempworks.CustomData.Assignments

  setup do
    integration =
      insert(:integration,
        integration: "tempworks",
        client: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        settings: %{
          "tempworks_region" => "test_tempworks_region",
          "sync_custom_data" => true,
          "only_active_assignments" => true
        },
        authentication: %{
          "access_token" => "test_access_token",
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "client_id",
          "client_secret" => "client_secret",
          "acr_values" => "acr_values",
          "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        }
      )

    custom_object =
      insert(:custom_object,
        integration: integration,
        external_entity_type: "assignment",
        whippy_organization_id: integration.whippy_organization_id
      )

    advance_custom_object =
      insert(:custom_object,
        integration: integration,
        external_entity_type: "tempworks_assignments",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object,
      advance_custom_object: advance_custom_object
    }
  end

  describe "process/1 for process_assignments_as_custom_object_records" do
    test "finds the assignment custom object and calls the converter with it, when the assignment belongs to a synced contact",
         %{
           integration: integration,
           advance_custom_object: advance_custom_object
         } do
      insert(:contact,
        integration: integration,
        external_contact_id: "41459",
        whippy_contact_id: "4321",
        external_organization_id: "654"
      )

      with_mocks([
        {HTTPoison, [], http_poison_mocks()},
        {Converter, [],
         [
           convert_external_resource_to_custom_object_record: fn parser_module,
                                                                 _integration,
                                                                 found_custom_object,
                                                                 _assignment ->
             assert parser_module == Sync.Clients.Tempworks.Parser
             assert found_custom_object.id == advance_custom_object.id
             {:ok, %CustomObjectRecord{}}
           end
         ]}
      ]) do
        assert :ok ==
                 perform_job(Assignments, %{
                   "type" => "process_advance_assignments_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(Converter.convert_external_resource_to_custom_object_record(:_, :_, :_, :_), 1)
      end
    end

    test "only fetches active assignments when the setting is enabled", %{integration: integration} do
      insert(:contact,
        integration: integration,
        external_contact_id: "1234",
        whippy_contact_id: "4321",
        external_organization_id: "654"
      )

      with_mocks([
        {HTTPoison, [], http_poison_mocks()},
        {Converter, [], converter_mocks()}
      ]) do
        assert :ok ==
                 perform_job(Assignments, %{
                   "type" => "process_advance_assignments_as_custom_object_records",
                   "integration_id" => integration.id
                 })
      end
    end

    test "does not save assignments that are not associated with existing external contact", %{
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], http_poison_mocks()},
        {Converter, [], converter_mocks()}
      ]) do
        assert :ok ==
                 perform_job(Assignments, %{
                   "type" => "process_advance_assignments_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_not_called(Converter.convert_external_resource_to_custom_object_record(:_, :_, :_, :_))
      end
    end

    test "logs an error when assignment custom object has not been synced", %{
      integration: integration,
      advance_custom_object: custom_object
    } do
      Sync.Repo.delete(custom_object)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(Assignments, %{
                          "type" => "process_advance_assignments_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No `tempworks_assignments` custom object found for assignment."
    end
  end

  describe "process/1 for process_assignment_custom_data_as_custom_object_records" do
    setup %{
      integration: integration,
      custom_object: assignment_custom_object
    } do
      insert(:custom_object_record,
        integration: integration,
        custom_object: assignment_custom_object,
        external_custom_object_record_id: "1234",
        whippy_organization_id: integration.whippy_organization_id
      )

      custom_data_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "assignment_custom_data",
          whippy_organization_id: integration.whippy_organization_id
        )

      _foreign_assoc_property =
        insert(:custom_property, custom_object: custom_data_object, whippy_custom_property: %{"label" => "assignmentId"})

      :ok
    end

    test "finds the assignment_custom_data custom object, pulls assignment custom data and calls the converter for each of them",
         %{
           integration: integration
         } do
      insert(:contact,
        integration: integration,
        external_contact_id: "59802",
        whippy_organization_id: integration.whippy_organization_id,
        external_organization_id: integration.external_organization_id,
        whippy_contact_id: "1"
      )

      with_mocks([
        {Converter, [],
         convert_bulk_external_resource_to_custom_object_record: fn parser_module,
                                                                    _integration,
                                                                    _found_custom_object,
                                                                    _,
                                                                    _ ->
           assert parser_module == Sync.Clients.Tempworks.Parser
           {:ok, %CustomObjectRecord{}}
         end},
        {HTTPoison, [],
         [
           get: fn url, _headers, _opts ->
             cond do
               url =~ "Search" -> list_assignment_fixture()
               url =~ "CustomData" -> assignment_custom_data_fixture()
             end
           end
         ]}
      ]) do
        assert :ok ==
                 perform_job(Assignments, %{
                   "type" => "process_assignments_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(Converter.convert_bulk_external_resource_to_custom_object_record(:_, :_, :_, :_, :_), 1)
      end
    end
  end

  defp converter_mocks do
    [
      convert_external_resource_to_custom_object_record: fn _parser_module,
                                                            _integration,
                                                            _employee_detail,
                                                            _custom_object ->
        {:ok, %CustomObjectRecord{}}
      end
    ]
  end

  defp http_poison_mocks do
    [
      get: fn _url, _header -> list_assignment_column_fixture() end,
      post: fn _url, _params, _headers, _opts -> list_advance_assignment_fixture() end
    ]
  end
end
