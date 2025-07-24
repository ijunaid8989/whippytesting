defmodule Sync.Workers.Whippy.WriterTest do
  use Sync.DataCase, async: false

  import Mock
  import Sync.Factory
  import Sync.Fixtures.WhippyClient

  alias Sync.Workers.Whippy.Writer

  setup do
    integration =
      insert(:integration,
        integration: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "scope" => "test_scope",
          "grant_type" => "client_credentials",
          "access_token" => "existing_valid_token",
          "token_expires_at" => DateTime.to_unix(DateTime.utc_now()) + 600,
          "acr_values" => "tenant:twtest pid:uuid"
        }
      )

    %{integration: integration}
  end

  describe "push_custom_objects/2" do
    test "updates the whippy custom object with associations when references are defined on the external custom property",
         %{
           integration: integration
         } do
      # prepare
      employee_custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee",
          whippy_custom_object: %{},
          whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326"
        )

      referenced_custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data",
          whippy_custom_object: %{},
          whippy_custom_object_id: Ecto.UUID.generate()
        )

      referenced_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: true,
          integration: integration,
          custom_object: referenced_custom_object,
          whippy_custom_object_id: referenced_custom_object.whippy_custom_object_id,
          external_custom_property: %{"key" => "employee_id", label: "Employee ID", type: "text"}
        )

      _referencing_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: true,
          integration: integration,
          custom_object: employee_custom_object,
          whippy_custom_object_id: employee_custom_object.whippy_custom_object_id,
          external_custom_property: %{
            "key" => "employee_id",
            "label" => "Employee ID",
            "type" => "text",
            "references" => [
              %{
                "type" => "one_to_one",
                "external_entity_type" => "employee_custom_data",
                "external_entity_property_key" => "employee_id"
              }
            ]
          }
        )

      expected_body_for_custom_object_with_associations =
        %{
          "editable" => false,
          "associations" => [
            %{
              "id" => nil,
              "delete" => nil,
              "type" => "one_to_one",
              "source_property_key" => "employee_id",
              "target_property_key" => "employee_id",
              "target_data_type_id" => referenced_custom_property.whippy_custom_object_id
            }
          ]
        }

      # act & assert
      with_mock(HTTPoison, [],
        request: fn :put, url, body, _header, _opts ->
          decoded_body = Jason.decode!(body)

          if String.contains?(url, "properties") do
            create_custom_property_fixture()
          else
            assert decoded_body == expected_body_for_custom_object_with_associations
            create_custom_object_fixture()
          end
        end
      ) do
        assert :ok == Writer.push_custom_objects(integration, 10)
      end
    end

    test """
         updates the whippy custom object with combined associations when both
         whippy_custom_property and external_custom_property have defined references/associations
         """,
         %{
           integration: integration
         } do
      # prepare
      dummy_custom_object_id = Ecto.UUID.generate()
      dummy_assoc_id = Ecto.UUID.generate()

      employee_custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee",
          whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326",
          whippy_organization_id: integration.whippy_organization_id,
          whippy_custom_object: %{
            "associations" => [
              %{
                "type" => "one_to_many",
                "source_property_key" => "employee_id",
                "target_property_key" => "employee_id",
                "target_data_type_id" => dummy_custom_object_id,
                "id" => dummy_assoc_id,
                "delete" => nil
              }
            ]
          }
        )

      referenced_custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data",
          whippy_organization_id: integration.whippy_organization_id
        )

      _referenced_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: true,
          integration: integration,
          custom_object: referenced_custom_object,
          external_custom_property: %{"key" => "employee_id", label: "Employee ID", type: "text"}
        )

      _referencing_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: true,
          integration: integration,
          custom_object: employee_custom_object,
          whippy_custom_object_id: employee_custom_object.whippy_custom_object_id,
          external_custom_property: %{
            "key" => "employee_id",
            "label" => "Employee ID",
            "type" => "text",
            "references" => [
              %{
                "type" => "one_to_one",
                "external_entity_type" => "employee_custom_data",
                "external_entity_property_key" => "employee_id"
              }
            ]
          }
        )

      expected_reference_one = %{
        "id" => nil,
        "delete" => nil,
        "type" => "one_to_one",
        "source_property_key" => "employee_id",
        "target_property_key" => "employee_id",
        "target_data_type_id" => referenced_custom_object.whippy_custom_object_id
      }

      expected_reference_two = %{
        "id" => dummy_assoc_id,
        "delete" => nil,
        "type" => "one_to_many",
        "source_property_key" => "employee_id",
        "target_property_key" => "employee_id",
        "target_data_type_id" => dummy_custom_object_id
      }

      # act & assert
      with_mock(HTTPoison, [],
        request: fn :put, url, body, _header, _opts ->
          decoded_body = Jason.decode!(body)

          if String.contains?(url, "properties") do
            create_custom_property_fixture()
          else
            assert Enum.member?(decoded_body["associations"], expected_reference_one)
            assert Enum.member?(decoded_body["associations"], expected_reference_two)
            create_custom_object_fixture()
          end
        end
      ) do
        assert :ok == Writer.push_custom_objects(integration, 10)
      end
    end

    @tag capture_log: true
    test "does not make a request to add associations to a whippy custom object when the referenced custom object does not exist",
         %{
           integration: integration
         } do
      # prepare
      employee_custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee",
          whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326"
        )

      _referencing_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: true,
          integration: integration,
          custom_object: employee_custom_object,
          external_custom_property: %{
            "key" => "employee_id",
            label: "Employee ID",
            type: "text",
            references: [
              %{
                "type" => "one_to_one",
                "external_entity_type" => "employee_custom_data",
                "external_entity_property_key" => "employee_id"
              }
            ]
          }
        )

      # act & assert
      with_mock(HTTPoison, [],
        request: fn :put, url, _body, _header, _opts ->
          # Assert that all the PUT requests are for custom properties and none for custom objects
          assert String.contains?(url, "properties")
          create_custom_property_fixture()
        end
      ) do
        assert :ok == Writer.push_custom_objects(integration, 10)
      end
    end
  end

  describe "push_custom_object_records/2" do
    test "makes a request to create custom object record in whippy", %{integration: integration} do
      # prepare
      custom_object = insert(:custom_object, integration: integration, external_entity_type: "employee")

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "tax_percent", "label" => "Tax Percent", "type" => "float"},
          external_custom_property: %{"key" => "tax_percent", "label" => "Tax Percent", "type" => "float"}
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "tax_percent_two", "label" => "Tax Percent Two", "type" => "float"},
          external_custom_property: %{"key" => "tax_percent_two", "label" => "Tax Percent Two", "type" => "float"}
        )

      custom_object_record =
        insert(:custom_object_record,
          integration: integration,
          whippy_organization_id: integration.whippy_organization_id,
          custom_object: custom_object,
          external_custom_object_record: %{"tax_percent" => nil, "tax_percent_two" => "0.5"},
          should_sync_to_whippy: true
        )

      insert(:custom_property_value,
        custom_object_record: custom_object_record,
        custom_property: custom_property_one,
        external_custom_property_value: nil
      )

      insert(:custom_property_value,
        custom_object_record: custom_object_record,
        custom_property: custom_property_two,
        external_custom_property_value: 0.5
      )

      expected_properties = %{
        "tax_percent" => nil,
        "tax_percent_two" => 0.5
      }

      # act & assert
      with_mock(HTTPoison, [],
        request: fn :put, _url, body, _header, _opts ->
          decoded_body = Jason.decode!(body)

          assert decoded_body["properties"] == expected_properties

          create_custom_object_record_fixture()
        end
      ) do
        assert :ok == Writer.push_custom_object_records(integration, 10)
      end
    end

    test "does not send empty string values to Whippy for custom data dates", %{integration: integration} do
      # prepare
      custom_object = insert(:custom_object, integration: integration, external_entity_type: "employee")

      custom_property =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "date_of_birth", "label" => "Date of Birth", "type" => "date"},
          external_custom_property: %{"key" => "date_of_birth", "label" => "Date of Birth", "type" => "date"}
        )

      custom_object_record =
        insert(:custom_object_record,
          integration: integration,
          whippy_organization_id: integration.whippy_organization_id,
          custom_object: custom_object,
          external_custom_object_record: %{"date_of_birth" => ""},
          should_sync_to_whippy: true
        )

      insert(:custom_property_value,
        custom_object_record: custom_object_record,
        custom_property: custom_property,
        external_custom_property_value: ""
      )

      # act & assert
      with_mock(HTTPoison, [],
        request: fn :put, _url, body, _header, _opts ->
          decoded_body = Jason.decode!(body)
          assert decoded_body["properties"] == %{"date_of_birth" => nil}
          create_custom_object_record_fixture()
        end
      ) do
        assert :ok == Writer.push_custom_object_records(integration, 10)
      end
    end
  end
end
