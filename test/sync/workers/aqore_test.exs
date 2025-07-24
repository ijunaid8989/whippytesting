defmodule Sync.Workers.AqoreTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Oban.Testing, only: [with_testing_mode: 2]
  import Sync.Factory

  alias Oban.Job
  alias Sync.Integrations
  alias Sync.Workers.Aqore

  setup do
    integration =
      insert(:integration,
        integration: "aqore",
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
          "tempworks_region" => "test_aqore_region",
          "sync_custom_data" => true,
          "only_active_assignments" => true
        }
      )

    %{integration: integration}
  end

  describe "aqore process" do
    test "push contacts to aqore when send_contacts_to_external_integrations settings is true", %{
      integration: integration
    } do
      expected_jobs = [
        "pull_users_from_whippy",
        "pull_users_from_aqore",
        "pull_candidates_from_aqore",
        "pull_contacts_from_aqore",
        "pull_contacts_from_whippy",
        "lookup_candidates_in_aqore",
        "push_contacts_to_aqore",
        "push_candidates_to_whippy",
        "pull_messages_from_whippy",
        "push_messages_to_aqore"
      ]

      {:ok, _integration} =
        Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

      with_testing_mode(:manual, fn ->
        Aqore.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
        enqueued_jobs = all_enqueued()
        jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
        assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
        assert Enum.member?(jobs_list, "push_contacts_to_aqore")
      end)
    end
  end

  test "don't push contacts to aqore when send_contacts_to_external_integrations settings is false", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_users_from_whippy",
      "pull_users_from_aqore",
      "pull_candidates_from_aqore",
      "pull_contacts_from_aqore",
      "pull_contacts_from_whippy",
      "lookup_candidates_in_aqore",
      "push_candidates_to_whippy",
      "pull_messages_from_whippy",
      "push_messages_to_aqore"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Aqore.process(%Job{args: %{"integration_id" => integration.id, "type" => "full_sync"}})
      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "push_contacts_to_aqore")
    end)
  end

  test "push contacts to aqore through daily sync when send_contacts_to_external_integrations settings is true", %{
    integration: integration
  } do
    expected_jobs = [
      "pull_users_from_whippy",
      "daily_pull_users_from_aqore",
      "daily_pull_candidates_from_aqore",
      "daily_pull_contacts_from_aqore",
      "pull_contacts_from_whippy",
      "lookup_candidates_in_aqore",
      "push_contacts_to_aqore",
      "push_candidates_to_whippy",
      "daily_pull_messages_from_whippy",
      "daily_push_comments_to_aqore"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => true}})

    with_testing_mode(:manual, fn ->
      Aqore.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      assert Enum.member?(jobs_list, "push_contacts_to_aqore")
    end)
  end

  test "don't push contacts to aqore through daily sync when send_contacts_to_external_integrations settings is false",
       %{
         integration: integration
       } do
    expected_jobs = [
      "pull_users_from_whippy",
      "daily_pull_users_from_aqore",
      "daily_pull_candidates_from_aqore",
      "pull_candidates_from_aqore",
      "daily_pull_contacts_from_aqore",
      "pull_contacts_from_whippy",
      "lookup_candidates_in_aqore",
      "push_candidates_to_whippy",
      "daily_pull_messages_from_whippy",
      "daily_push_comments_to_aqore"
    ]

    {:ok, _integration} =
      Integrations.update_integration(integration, %{settings: %{"send_contacts_to_external_integrations" => false}})

    with_testing_mode(:manual, fn ->
      Aqore.process(%Job{
        args: %{"integration_id" => integration.id, "type" => "daily_sync"},
        inserted_at: DateTime.utc_now()
      })

      enqueued_jobs = all_enqueued()
      jobs_list = Enum.map(enqueued_jobs, fn job -> job.meta["name"] end)
      assert Enum.all?(jobs_list, &Enum.member?(expected_jobs, &1))
      refute Enum.member?(jobs_list, "push_contacts_to_aqore")
    end)
  end
end
