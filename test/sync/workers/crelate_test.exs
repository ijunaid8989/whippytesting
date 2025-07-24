defmodule Sync.Workers.CrelateTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Oban.Testing, only: [with_testing_mode: 2]
  import Sync.Factory

  alias Oban.Job
  alias Sync.Integrations
  alias Sync.Workers.Crelate

  setup do
    integration =
      insert(:integration,
        integration: "Crelate",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "whippy_api_key" => "test_whippy_api_key",
          "external_api_key" => "sx9fgdr8c7gn4tdpyds1fmfybo",
          "client_id" => "test_client_id",
          "acr_values" => "tenant:twtest pid:uuid",
          "client_secret" => "test_client_secret"
        },
        settings: %{
          "sync_custom_data" => false,
          "only_active_assignments" => false,
          "send_contacts_to_external_integrations" => true
        }
      )

    %{integration: integration}
  end

  describe "crelate process" do
    test "pull contacts from crelate through daily sync when send_contacts_to_external_integrations settings is true", %{
      integration: integration
    } do
      expected_jobs = [
        "daily_pull_contacts_from_crelate",
        "daily_pull_contacts_from_whippy",
        "daily_push_contacts_to_crelate",
        "daily_push_contacts_to_whippy",
        "daily_pull_messages_from_whippy",
        "daily_push_messages_to_crelate"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

      with_testing_mode(:manual, fn ->
        Crelate.process(%Job{
          args: %{"integration_id" => integration.id, "type" => "daily_sync"},
          inserted_at: DateTime.utc_now()
        })

        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        assert Enum.member?(jobs_list, "daily_pull_contacts_from_crelate")
      end)
    end

    test "don't push contacts to crelate through daily sync when send_contacts_to_external_integrations settings is false",
         %{
           integration: integration
         } do
      expected_jobs = [
        "daily_pull_contacts_from_crelate",
        "daily_pull_contacts_from_whippy",
        "daily_push_contacts_to_whippy",
        "daily_pull_messages_from_whippy",
        "daily_push_messages_to_crelate"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

      with_testing_mode(:manual, fn ->
        Crelate.process(%Job{
          args: %{"integration_id" => integration.id, "type" => "daily_sync"},
          inserted_at: DateTime.utc_now()
        })

        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        refute Enum.member?(jobs_list, "daily_push_contacts_to_crelate")
      end)
    end

    test "push contacts to crelate when send_contacts_to_external_integrations settings is true", %{
      integration: integration
    } do
      expected_jobs = [
        "pull_contacts_from_crelate",
        "pull_contacts_from_whippy",
        "push_contacts_to_crelate",
        "push_contacts_to_whippy",
        "pull_messages_from_whippy",
        "push_messages_to_crelate"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

      with_testing_mode(:manual, fn ->
        Crelate.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        assert Enum.member?(jobs_list, "push_contacts_to_crelate")
      end)
    end

    test "don't push contacts to crelate when send_contacts_to_external_integrations settings is false", %{
      integration: integration
    } do
      expected_jobs = [
        "pull_contacts_from_crelate",
        "pull_contacts_from_whippy",
        "push_contacts_to_whippy",
        "pull_messages_from_whippy",
        "push_messages_to_crelate"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

      with_testing_mode(:manual, fn ->
        Crelate.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        refute Enum.member?(jobs_list, "push_contacts_to_crelate")
      end)
    end
  end
end
