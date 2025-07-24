defmodule Sync.Workers.Avionte.CustomData.CustomObjectsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Avionte.CustomData.CustomObjects

  @external_entity_types ["talent", "avionte_contact", "companies", "placements", "jobs"]

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

    %{integration: integration}
  end

  describe "process/1 for type pull_custom_objects_from_whippy" do
    test "makes request to whippy to fetch custom objects and their properties", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.list_custom_objects_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "pull_custom_objects_from_whippy",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(HTTPoison.request(:get, :_, :_, :_, :_), 1)
      end
    end

    test "saves custom objects and custom properties", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.list_custom_objects_fixture()
        end
      ) do
        perform_job(CustomObjects, %{
          "type" => "pull_custom_objects_from_whippy",
          "integration_id" => integration.id
        })

        assert [%CustomObject{custom_properties: [%CustomProperty{}]}] =
                 CustomObject |> Repo.all() |> Repo.preload(:custom_properties)
      end
    end
  end

  describe "process/1 for type pull_custom_objects_from_avionte" do
    test "creates a custom_object for avionte talents", %{
      integration: integration
    } do
      assert :ok ==
               perform_job(CustomObjects, %{
                 "type" => "pull_custom_objects_from_avionte",
                 "integration_id" => integration.id
               })

      custom_objects = CustomObject |> Repo.all() |> Repo.preload(:custom_properties)

      assert length(custom_objects) == length(@external_entity_types)
      assert Enum.all?(custom_objects, fn co -> co.external_entity_type in @external_entity_types end)
    end

    test "does not create new custom_objects when they have already been pulled from whippy", %{
      integration: integration
    } do
      Enum.each(@external_entity_types, fn entity_type ->
        insert(:custom_object,
          integration: integration,
          external_entity_type: entity_type,
          whippy_organization_id: integration.whippy_organization_id
        )
      end)

      assert :ok ==
               perform_job(CustomObjects, %{
                 "type" => "pull_custom_objects_from_avionte",
                 "integration_id" => integration.id
               })

      custom_objects = CustomObject |> Repo.all() |> Repo.preload(:custom_properties)

      assert length(custom_objects) == length(@external_entity_types)
    end
  end

  describe "process/1 for type push_custom_objects_to_whippy" do
    setup %{integration: integration} do
      custom_object =
        insert(:custom_object,
          integration: integration,
          whippy_custom_object_id: nil,
          whippy_organization_id: integration.whippy_organization_id
        )

      insert(:custom_property,
        custom_object: custom_object,
        whippy_custom_property_id: nil
      )

      :ok
    end

    test "makes request to whippy to push custom objects", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.create_custom_object_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "push_custom_objects_to_whippy",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(HTTPoison.request(:post, :_, :_, :_, :_), 1)
      end
    end

    test "updates custom objects with whippy values", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.create_custom_object_fixture()
        end
      ) do
        perform_job(CustomObjects, %{
          "type" => "push_custom_objects_to_whippy",
          "integration_id" => integration.id
        })

        assert [
                 %CustomObject{
                   whippy_custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                   whippy_custom_object: %{
                     "created_at" => "2023-07-27T14:56:01",
                     "id" => "a3b0e0a0-a278-4b29-9386-129967265856",
                     "key" => "contact_address",
                     "custom_properties" => [
                       %{
                         "created_at" => "2023-07-27T14:56:01",
                         "custom_object_id" => "a3b0e0a0-a278-4b29-9386-129967265856",
                         "default" => nil,
                         "id" => "095c2507-fb20-4f05-b586-ddb54ce77e10",
                         "key" => "city",
                         "label" => "City",
                         "required" => false,
                         "type" => "text",
                         "updated_at" => "2023-07-27T14:56:01"
                       }
                     ],
                     "label" => "Contact Address",
                     "updated_at" => "2023-07-27T14:56:01"
                   }
                 }
               ] =
                 Repo.all(CustomObject)
      end
    end
  end

  describe "process/1 for type push_custom_object_records_to_whippy" do
    setup %{integration: integration} do
      custom_object =
        insert(:custom_object,
          integration: integration,
          whippy_custom_object_id: "test_whippy_custom_object_id",
          whippy_organization_id: integration.whippy_organization_id
        )

      custom_property =
        insert(:custom_property,
          custom_object: custom_object,
          whippy_custom_property_id: "095c2507-fb20-4f05-b586-ddb54ce77e10",
          whippy_custom_property: %{
            "key" => "test_key",
            "created_at" => "2023-07-28T12:13:45",
            "id" => "095c2507-fb20-4f05-b586-ddb54ce77e10"
          }
        )

      unsynced_custom_object_record =
        insert(:custom_object_record,
          integration: integration,
          whippy_organization_id: integration.whippy_organization_id,
          custom_object: custom_object,
          external_custom_object_record_id: "test_external_id",
          whippy_custom_object_record_id: nil
        )

      insert(:custom_property_value,
        custom_object_record: unsynced_custom_object_record,
        custom_property: custom_property,
        external_custom_property_value: "New York",
        whippy_custom_property_id: "095c2507-fb20-4f05-b586-ddb54ce77e10"
      )

      :ok
    end

    test "makes request to whippy to push custom object records", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.create_custom_object_record_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "push_custom_object_records_to_whippy",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(HTTPoison.request(:post, :_, :_, :_, :_), 1)
      end
    end

    test "updates custom object records with whippy values", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn _method, _url, _body, _header, _opts ->
          Fixtures.WhippyClient.create_custom_object_record_fixture()
        end
      ) do
        perform_job(CustomObjects, %{
          "type" => "push_custom_object_records_to_whippy",
          "integration_id" => integration.id
        })

        assert [%CustomObjectRecord{whippy_custom_object_record_id: whippy_id}] = Repo.all(CustomObjectRecord)
        assert whippy_id
      end
    end
  end
end
