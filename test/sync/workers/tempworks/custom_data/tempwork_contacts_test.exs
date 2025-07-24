defmodule Sync.Workers.Tempworks.CustomData.TempworkContactsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory
  import Sync.Fixtures.TempworksClient

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Tempworks.CustomData.Employees

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
        external_entity_type: "tempworks_contacts",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end

  describe "process/1 for process_contact_details_as_custom_object_records for tempwork contacts" do
    setup %{integration: integration} do
      _synced_contact =
        insert(:contact,
          integration: integration,
          external_organization_id: "test_external_organization_id",
          external_contact_id: "contact-69",
          whippy_contact_id: "test_whippy_contact_id"
        )

      :ok
    end

    test "finds the contact custom object, pulls contact details and calls the converter for each of them", %{
      integration: integration
    } do
      with_mocks([
        {Converter, [], converter_mocks()},
        {HTTPoison, [], http_poison_mocks()},
        {HTTPoison, [], http_poison_mocks_for_contact_detail()},
        {HTTPoison, [], contact_custom_data_mocks()}
      ]) do
        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "process_contact_details_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(
          Sync.Workers.CustomData.Converter.convert_bulk_external_resource_to_custom_object_record(:_, :_, :_, :_, :_),
          1
        )
      end
    end

    test "logs an error when the contact custom object is not found" do
      integration = insert(:integration)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(Employees, %{
                          "type" => "process_contact_details_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No custom object found for tempwork contact."
    end

    test "logs an error when the contact custom object is not yet synced to whippy" do
      integration = insert(:integration)

      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "tempworks_contacts",
        whippy_organization_id: integration.whippy_organization_id
      )

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(Employees, %{
                          "type" => "process_contact_details_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "contact custom_object not synced to whippy."
    end
  end

  describe "process/1 for process_contact_details_as_custom_object_records" do
    setup %{integration: integration, custom_object: employee_custom_object} do
      insert(:custom_object_record,
        integration: integration,
        custom_object: employee_custom_object,
        external_custom_object_record_id: "1234"
      )

      custom_data_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data",
          whippy_organization_id: integration.whippy_organization_id
        )

      _foreign_assoc_property =
        insert(:custom_property, custom_object: custom_data_object, whippy_custom_property: %{"label" => "contactId"})

      :ok
    end
  end

  defp converter_mocks do
    [
      convert_external_resource_to_custom_object_record: fn _integration,
                                                            _custom_data,
                                                            _custom_object,
                                                            _external_id,
                                                            _extra_params ->
        {:ok, %CustomObjectRecord{}}
      end,
      convert_bulk_external_resource_to_custom_object_record: fn _integration,
                                                                 _custom_data,
                                                                 _custom_object,
                                                                 _external_id,
                                                                 _extra_params ->
        {:ok, %CustomObjectRecord{}}
      end
    ]
  end

  defp http_poison_mocks do
    [
      get: fn _url, _headers -> list_contacts_fixture(limit: 1) end
    ]
  end

  defp http_poison_mocks_for_contact_detail do
    [
      get: fn _url, _headers -> list_contacts_details_fixture() end
    ]
  end

  def contact_custom_data_mocks do
    [get: fn _url, _headers, _opts -> list_contacts_custom_data_fixture() end]
  end
end
