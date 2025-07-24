defmodule Sync.Workers.Loxo.PersonEventsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory

  alias Sync.Fixtures
  alias Sync.Workers.Loxo.PersonEvents

  setup do
    integration =
      insert(:integration,
        integration: "loxo",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        client: :loxo,
        authentication: %{
          "external_api_key" => "test_loxo_api_key",
          "whippy_api_key" => "test_whippy_api_key",
          "agency_slug" => "test_agency_slug"
        }
      )

    # The tests of people assume the users have already been synced
    insert(:user, integration: integration, external_user_id: "12245", whippy_user_id: "1")

    %{integration: integration}
  end

  describe "process/1" do
    test "pulls daily messages from Whippy and processes them", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_pull_daily_messages)) do
        log =
          capture_log(fn ->
            assert :ok ==
                     perform_job(PersonEvents, %{
                       "type" => "daily_pull_messages_from_whippy",
                       "integration_id" => integration.id,
                       "day" => "2024-07-25"
                     })
          end)

        # Assertions for the expected behavior after pulling daily messages
        assert log =~
                 "Loxo integration #{integration.id} daily sync for 2024-07-25. Pulling messages from Whippy."
      end
    end

    test "pushes daily person activities to Loxo", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:loxo_push_daily_activities)) do
        log =
          capture_log(fn ->
            assert :ok ==
                     perform_job(PersonEvents, %{
                       "type" => "daily_push_person_activities_to_loxo",
                       "integration_id" => integration.id,
                       "day" => "2024-07-25"
                     })
          end)

        assert log =~
                 "Loxo integration #{integration.id} daily sync for 2024-07-25. Pushing messages to Loxo."
      end
    end

    test "handles unknown job types", %{integration: integration} do
      captured_log =
        capture_log(fn ->
          assert :ok ==
                   perform_job(PersonEvents, %{
                     "type" => "unknown_type",
                     "integration_id" => integration.id
                   })
        end)

      assert captured_log =~ "Unknown job type:"
    end
  end

  defp httpoison_mock(:whippy_pull_daily_messages) do
    [
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_conversations_fixture() end
    ]
  end

  defp httpoison_mock(:loxo_push_daily_activities) do
    [
      post: fn _url, _body, _headers -> Fixtures.LoxoClient.create_person_event_fixture() end
    ]
  end
end
