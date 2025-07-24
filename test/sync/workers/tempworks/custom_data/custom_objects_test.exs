defmodule Sync.Workers.Tempworks.CustomData.CustomObjectsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Tempworks.CustomData.CustomObjects

  @external_entity_types [
    "employee",
    "assignment",
    "tempworks_contacts",
    "job_orders",
    "customers"
  ]

  setup do
    integration =
      insert(:integration,
        integration: "tempworks",
        client: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "access_token" => "test_access_token",
          "acr_values" => "test_acr_values",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "expires_in" => 3600,
          "refresh_token" => "test_refresh_token",
          "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
          "token_type" => "Bearer",
          "whippy_api_key" => "test_whippy_api_key"
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

  describe "process/1 for type pull_custom_objects_from_tempworks" do
    test "creates custom_objects for tempworks custom data if such haven't been pulled from whippy", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "pull_custom_objects_from_tempworks",
                   "integration_id" => integration.id
                 })

        custom_objects = CustomObject |> Repo.all() |> Repo.preload(:custom_properties)

        assert length(custom_objects) == length(@external_entity_types)
        assert Enum.all?(custom_objects, fn co -> co.external_entity_type in @external_entity_types end)
      end
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

      with_mock(HTTPoison, [], http_poison_mocks()) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "pull_custom_objects_from_tempworks",
                   "integration_id" => integration.id
                 })

        custom_objects = CustomObject |> Repo.all() |> Repo.preload(:custom_properties)

        assert length(custom_objects) == length(@external_entity_types)
      end
    end

    @tag capture_log: true
    test "does not create custom object for assignment_custom_data when Tempworks API returns an error", %{
      integration: integration
    } do
      with_mock(HTTPoison, [],
        get: fn
          url, _headers, _opts ->
            cond do
              url =~ "Assignments" -> {:error, %HTTPoison.Error{reason: :timeout}}
              url =~ "CustomData" -> Fixtures.TempworksClient.get_employee_custom_data_fixture()
              url =~ "Employees" -> Fixtures.TempworksClient.list_employees_fixture(limit: 1)
              url =~ "columns" -> Fixtures.TempworksClient.list_employee_column_fixture()
              url =~ "Contacts" -> Fixtures.TempworksClient.list_contacts_fixture(limit: 1)
              url =~ "JobOrders" -> {:error, %HTTPoison.Error{reason: :timeout}}
              url =~ "Customers" -> {:error, %HTTPoison.Error{reason: :timeout}}
            end
        end,
        get: fn
          url, _headers ->
            cond do
              url =~ "columns" -> Fixtures.TempworksClient.list_employee_column_fixture()
            end
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "pull_custom_objects_from_tempworks",
                   "integration_id" => integration.id
                 })

        custom_objects = Repo.all(CustomObject)

        assert length(custom_objects) == length(@external_entity_types)
      end
    end

    defp http_poison_mocks do
      [
        get: fn
          url, _headers, _opts ->
            cond do
              url =~ "CustomData" -> Fixtures.TempworksClient.get_employee_custom_data_fixture()
              url =~ "Assignments" -> Fixtures.TempworksClient.list_employee_assignments_fixture()
              url =~ "Employees" -> Fixtures.TempworksClient.list_employees_fixture(limit: 1)
              url =~ "JobOrders" -> Fixtures.TempworksClient.list_job_orders_fixture()
              url =~ "Customers" -> Fixtures.TempworksClient.list_customer_fixture()
              url =~ "columns" -> Fixtures.TempworksClient.list_employee_column_fixture()
              url =~ "Contacts" -> Fixtures.TempworksClient.list_contacts_fixture(limit: 1)
            end
        end,
        get: fn
          url, _headers ->
            cond do
              url =~ "columns" -> Fixtures.TempworksClient.list_employee_column_fixture()
            end
        end
      ]
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
        integration: integration,
        custom_object: custom_object,
        whippy_custom_property_id: nil,
        errors: %{}
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

        assert_called_exactly(HTTPoison.request(:post, :_, :_, :_, :_), 2)
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

  describe "process/1 for type push_custom_objects_to_whippy when properties have references" do
    setup [:with_custom_property_with_references]

    test """
         makes a request to create custom properties in whippy, then makes a request to update
         the custom_object with associations
         """,
         context do
      %{
        integration: integration,
        employee_custom_object: employee_custom_object
      } = context

      with_mock(HTTPoison, [],
        request: fn method, url, body, _header, _opts ->
          case {method, url} do
            {:post, "http://localhost:4000/v1/custom_objects"} ->
              Fixtures.WhippyClient.create_custom_object_fixture()

            {:put, "http://localhost:4000/v1/custom_objects" <> _remainder} ->
              assert Jason.decode!(body) ==
                       %{
                         "associations" => [
                           %{
                             "id" => nil,
                             "delete" => nil,
                             "source_property_key" => "employee_id",
                             "target_data_type_id" => employee_custom_object.whippy_custom_object_id,
                             "target_property_key" => "employee_id",
                             "type" => "many_to_one"
                           }
                         ],
                         "editable" => false
                       }

              Fixtures.WhippyClient.create_custom_object_fixture()

            _ ->
              Fixtures.WhippyClient.create_custom_property_fixture()
          end
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "push_custom_objects_to_whippy",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(HTTPoison.request(:post, :_, :_, :_, :_), 2)
      end
    end
  end

  describe "process/1 for type push_custom_objects_to_whippy when properties have whippy_associations" do
    setup [:with_custom_property_with_whippy_associations]

    test """
         makes a request to create custom properties in whippy, then makes a request to update
         the custom_object with whippy_associations
         """,
         context do
      %{
        integration: integration
      } = context

      with_mock(HTTPoison, [],
        request: fn method, url, body, _header, _opts ->
          case {method, url} do
            {:post, "http://localhost:4000/v1/custom_objects"} ->
              Fixtures.WhippyClient.create_custom_object_fixture()

            {:put, "http://localhost:4000/v1/custom_objects" <> _remainder} ->
              assert Jason.decode!(body) ==
                       %{
                         "whippy_associations" => [
                           %{
                             "source_property_key" => "contact_id",
                             "target_property_key" => "external_id",
                             "target_whippy_resource" => "contact",
                             "target_property_key_prefix" => "cont-",
                             "type" => "one_to_one",
                             "id" => nil,
                             "delete" => nil
                           }
                         ],
                         "editable" => false
                       }

              Fixtures.WhippyClient.create_custom_object_fixture()

            _ ->
              Fixtures.WhippyClient.create_custom_property_fixture()
          end
        end
      ) do
        assert :ok ==
                 perform_job(CustomObjects, %{
                   "type" => "push_custom_objects_to_whippy",
                   "integration_id" => integration.id
                 })
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

  def with_custom_property_with_references(%{integration: integration}) do
    employee_custom_object =
      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326",
        external_entity_type: "employee",
        whippy_organization_id: integration.whippy_organization_id
      )

    employee_id_custom_property =
      insert(:custom_property,
        integration: integration,
        custom_object: employee_custom_object,
        whippy_custom_property_id: Ecto.UUID.generate(),
        whippy_custom_property: %{
          "key" => "employee_id"
        }
      )

    assignment_custom_object =
      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: nil,
        external_entity_type: "assignment",
        whippy_organization_id: integration.whippy_organization_id
      )

    insert(:custom_property,
      integration: integration,
      custom_object: assignment_custom_object,
      whippy_custom_property_id: nil,
      errors: %{},
      external_custom_property: %{
        "key" => "employee_id",
        "type" => "text",
        "references" => [
          %{
            "external_entity_type" => "employee",
            "external_entity_property_key" => "employee_id",
            "type" => "many_to_one"
          }
        ]
      }
    )

    %{
      integration: integration,
      employee_custom_object: employee_custom_object,
      employee_id_custom_property: employee_id_custom_property
    }
  end

  def with_custom_property_with_whippy_associations(%{integration: integration}) do
    custom_object =
      insert(:custom_object,
        integration: integration,
        whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326",
        external_entity_type: "tempworks_contacts",
        whippy_organization_id: integration.whippy_organization_id
      )

    insert(:custom_property,
      integration: integration,
      custom_object: custom_object,
      whippy_custom_property_id: nil,
      external_custom_property: %{
        "key" => "contact_id",
        "type" => "text",
        "whippy_associations" => [
          %{
            "type" => "one_to_one",
            "target_whippy_resource" => "contact",
            "target_property_key_prefix" => "cont-",
            "source_property_key" => "contact_id",
            "target_property_key" => "external_id"
          }
        ]
      }
    )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end
end
