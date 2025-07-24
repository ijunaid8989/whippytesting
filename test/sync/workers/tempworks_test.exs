defmodule Sync.Workers.TempworksTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Oban.Testing, only: [with_testing_mode: 2]
  import Sync.Factory

  alias Oban.Job
  alias Sync.Integrations
  alias Sync.Workers.Tempworks

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
          "acr_values" => "tenant:twtest pid:uuid",
          "refresh_token" => "test_refresh_token",
          "token_type" => "Bearer"
        },
        settings: %{
          "tempworks_region" => "test_tempworks_region",
          "sync_custom_data" => true,
          "only_active_assignments" => true
        }
      )

    %{integration: integration}
  end

  describe "tempworks process" do
    test "push contacts to tempworks when send_contacts_to_external_integrations settings is true", %{
      integration: integration
    } do
      expected_jobs = [
        "pull_messages_from_whippy",
        "push_messages_to_tempworks",
        "push_employees_to_whippy",
        "push_contacts_to_tempworks",
        "lookup_contacts_in_tempworks",
        "pull_contacts_from_whippy",
        "pull_employees_from_tempworks",
        "pull_contacts_from_tempworks",
        "pull_branches_from_tempworks"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

      with_testing_mode(:manual, fn ->
        Tempworks.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        assert Enum.member?(jobs_list, "push_contacts_to_tempworks")
      end)
    end
  end

  test "don't push contacts to tempworks when send_contacts_to_external_integrations settings is false", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_messages_from_whippy",
      "push_messages_to_tempworks",
      "push_employees_to_whippy",
      "lookup_contacts_in_tempworks",
      "pull_contacts_from_whippy",
      "pull_employees_from_tempworks",
      "pull_contacts_from_tempworks",
      "pull_branches_from_tempworks"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Tempworks.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "push_contacts_to_tempworks")
    end)
  end

  test "push contacts to tempworks through daily sync when send_contacts_to_external_integrations settings is true", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_branches_from_tempworks",
      "pull_users_from_whippy",
      "daily_pull_employees_from_tempworks",
      "daily_pull_contacts_from_tempworks",
      "daily_pull_contacts_from_whippy",
      "lookup_contacts_in_tempworks",
      "daily_push_contacts_to_tempworks",
      "daily_push_employees_to_whippy",
      "daily_pull_messages_from_whippy",
      "daily_push_messages_to_tempworks"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

    with_testing_mode(:manual, fn ->
      Tempworks.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      assert Enum.member?(jobs_list, "daily_push_contacts_to_tempworks")
    end)
  end

  test "don't push contacts to tempworks through daily sync when send_contacts_to_external_integrations settings is false",
       %{
         integration: integration
       } do
    expected_jobs = [
      "pull_branches_from_tempworks",
      "pull_users_from_whippy",
      "daily_pull_employees_from_tempworks",
      "daily_pull_contacts_from_tempworks",
      "daily_pull_contacts_from_whippy",
      "lookup_contacts_in_tempworks",
      "daily_push_employees_to_whippy",
      "daily_pull_messages_from_whippy",
      "daily_push_messages_to_tempworks"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Tempworks.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "daily_push_contacts_to_tempworks")
    end)
  end
end
