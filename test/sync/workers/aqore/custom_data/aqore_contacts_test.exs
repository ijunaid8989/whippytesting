defmodule Sync.Workers.Aqore.CustomData.AqoreContactsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.Aqore.CustomData.AqoreContacts
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
        external_entity_type: "aqore_contact",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end

  describe "process/1 for process_contacts_as_custom_object_records" do
    test "finds the contact custom object and calls the converter with it", %{
      integration: integration,
      custom_object: custom_object
    } do
      with_mock(Converter, [],
        convert_external_contacts_to_custom_object_records: fn parser_module,
                                                               _integration,
                                                               found_custom_object,
                                                               _condition ->
          assert parser_module == Sync.Clients.Aqore.Parser
          assert custom_object.id == found_custom_object.id
          [{:ok, %CustomObjectRecord{}}]
        end
      ) do
        assert :ok ==
                 perform_job(AqoreContacts, %{
                   "type" => "process_contacts_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(
          Converter.convert_external_contacts_to_custom_object_records(:_, :_, :_, :_),
          1
        )
      end
    end

    test "logs an error when the contact custom object is not found" do
      integration = insert(:integration)

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreContacts, %{
                          "type" => "process_contacts_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No custom object found for contacts."
    end

    test "logs an error when the contact custom object is not yet synced to whippy" do
      integration = insert(:integration)

      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "candidate"
      )

      assert capture_log(fn ->
               assert :ok ==
                        perform_job(AqoreContacts, %{
                          "type" => "process_contacts_as_custom_object_records",
                          "integration_id" => integration.id
                        })
             end) =~ "No custom object found for contacts."
    end
  end
end
