defmodule Sync.Workers.Tempworks.CustomData.JobOrdersTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory
  import Sync.Fixtures.TempworksClient

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Tempworks.CustomData.JobOrders

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
        external_entity_type: "job_orders",
        whippy_organization_id: integration.whippy_organization_id
      )

    %{
      integration: integration,
      custom_object: custom_object
    }
  end

  describe "process/1 for process_job_orders_custom_data_as_custom_object_records" do
    setup %{
      integration: integration,
      custom_object: job_order_custom_object
    } do
      insert(:custom_object_record,
        integration: integration,
        custom_object: job_order_custom_object,
        external_custom_object_record_id: "1234",
        whippy_organization_id: integration.whippy_organization_id
      )

      custom_data_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "job_order_custom_data",
          whippy_organization_id: integration.whippy_organization_id
        )

      _foreign_assoc_property =
        insert(:custom_property, custom_object: custom_data_object, whippy_custom_property: %{"label" => "orderId"})

      :ok
    end

    test "finds the job_orders_custom_data custom object, pulls job_order custom data and calls the converter for each of them",
         %{
           integration: integration
         } do
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
               url =~ "Search" -> list_job_orders_fixture()
               url =~ "CustomData" -> list_job_orders_custom_data_fixture()
             end
           end
         ]}
      ]) do
        assert :ok ==
                 perform_job(JobOrders, %{
                   "type" => "process_job_orders_as_custom_object_records",
                   "integration_id" => integration.id
                 })

        assert_called_exactly(Converter.convert_bulk_external_resource_to_custom_object_record(:_, :_, :_, :_, :_), 1)
      end
    end
  end
end
