defmodule Sync.Workers.AvionteTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Oban.Testing, only: [with_testing_mode: 2]
  import Sync.Factory

  alias Oban.Job
  # alias Sync.Contacts.CustomObjectRecord
  alias Sync.Integrations
  alias Sync.Workers.Avionte

  setup do
    integration =
      insert(:integration,
        integration: "avionte",
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
          "acr_values" => "tenant:twtest pid:uuid",
          "refresh_token" => "test_refresh_token",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        },
        settings: %{
          "sync_custom_data" => true,
          "only_active_assignments" => true,
          "allow_advanced_custom_data" => true
        }
      )

    %{integration: integration}
  end

  describe "avionte process" do
    test "push contacts to avionte when send_contacts_to_external_integrations settings is true", %{
      integration: integration
    } do
      expected_jobs = [
        "pull_branches_from_avionte",
        "pull_users_from_whippy",
        "pull_users_from_avionte",
        "pull_talents_from_avionte",
        "pull_contacts_from_avionte",
        "pull_contacts_from_whippy",
        "push_contacts_to_avionte",
        "push_talents_to_whippy"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

      with_testing_mode(:manual, fn ->
        Avionte.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        assert Enum.member?(jobs_list, "push_contacts_to_avionte")
      end)
    end
  end

  test "don't push contacts to avionte when send_contacts_to_external_integrations settings is false", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_branches_from_avionte",
      "pull_users_from_whippy",
      "pull_users_from_avionte",
      "pull_talents_from_avionte",
      "pull_contacts_from_avionte",
      "pull_contacts_from_whippy",
      "push_talents_to_whippy"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Avionte.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "push_contacts_to_avionte")
    end)
  end

  test "push contacts to avionte through daily sync when send_contacts_to_external_integrations settings is true", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_contacts_from_whippy",
      "push_contacts_to_avionte",
      "daily_pull_messages_from_whippy",
      "daily_push_talent_activities_to_avionte"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

    with_testing_mode(:manual, fn ->
      Avionte.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      assert Enum.member?(jobs_list, "push_contacts_to_avionte")
    end)
  end

  test "don't push contacts to avionte through daily sync when send_contacts_to_external_integrations settings is false",
       %{
         integration: integration
       } do
    expected_jobs = [
      "pull_contacts_from_whippy",
      "daily_pull_messages_from_whippy",
      "daily_push_talent_activities_to_avionte"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Avionte.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "push_contacts_to_avionte")
    end)
  end

  describe "process/1 custom_data_sync" do
    setup_with_mocks([
      {Sync.Utils.Parsers.CustomDataUtil, [:passthrough], [map_custom_property_values: fn _, _ -> [] end]},
      {Sync.Workers.Whippy.Reader, [], [pull_custom_objects: fn _, _, _ -> :ok end]},
      {Sync.Workers.Whippy.Writer, [],
       [
         push_custom_object_records: fn _, _ -> :ok end,
         push_custom_objects: fn _, _ -> :ok end
       ]}
    ]) do
      :ok
    end

    @tag capture_log: true
    test "schedules the expected jobs", %{integration: integration} do
      expected_jobs = [
        "pull_custom_objects_from_whippy",
        "pull_custom_objects_from_avionte",
        "push_custom_objects_to_whippy",
        "process_talents_as_custom_object_records",
        "process_contacts_as_custom_object_records",
        "process_companies_as_custom_object_records",
        "process_placements_as_custom_object_records",
        "process_jobs_as_custom_object_records",
        "push_custom_object_records_to_whippy"
      ]

      with_testing_mode(:manual, fn ->
        Avionte.process(%Job{args: %{"integration_id" => integration.id, "type" => "custom_data_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      end)
    end

    # @tag capture_log: true
    # test "converts existing contacts to custom object records", %{integration: integration} do
    #   _talent_object =
    #     insert(:custom_object,
    #       integration: integration,
    #       external_entity_type: "talent",
    #       whippy_custom_object_id: "test_whippy_id",
    #       whippy_organization_id: integration.whippy_organization_id
    #     )

    #   _contact =
    #     insert(:contact,
    #       integration: integration,
    #       external_contact_id: "test_external_id",
    #       whippy_organization_id: integration.whippy_organization_id,
    #       external_organization_id: integration.external_organization_id,
    #       whippy_contact_id: "1235"
    #     )

    #   with_testing_mode(:manual, fn ->
    #     perform_job(Avionte, %{"integration_id" => integration.id, "type" => "custom_data_sync"})

    # assert %{success: 6} = Oban.drain_queue(queue: :avionte, with_scheduled: true)

    #     assert [%CustomObjectRecord{external_custom_object_record_id: "test_external_id", should_sync_to_whippy: true}] =
    #              Sync.Repo.all(CustomObjectRecord)
    #   end)
    # end

    # @tag capture_log: true
    # test "pushes custom object records to whippy", %{integration: integration} do
    #   _talent_object =
    #     insert(:custom_object,
    #       integration: integration,
    #       external_entity_type: "talent",
    #       whippy_custom_object_id: "test_whippy_id",
    #       whippy_organization_id: integration.whippy_organization_id
    #     )

    #   _contact =
    #     insert(:contact,
    #       integration: integration,
    #       external_contact_id: "test_external_id",
    #       whippy_organization_id: integration.whippy_organization_id,
    #       external_organization_id: integration.external_organization_id,
    #       whippy_contact_id: "1235"
    #     )

    #   with_testing_mode(:manual, fn ->
    #     perform_job(Avionte, %{"integration_id" => integration.id, "type" => "custom_data_sync"})

    #     assert %{success: 6} = Oban.drain_queue(queue: :avionte, with_scheduled: true)
    #     assert called(Sync.Workers.Whippy.Writer.push_custom_object_records(:_, :_))
    #   end)
    # end
  end
end
