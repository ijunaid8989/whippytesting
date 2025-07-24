defmodule Sync.Workers.Crelate.CrelateActivitiesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Activities.Activity
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Crelate.Activities

  setup do
    integration =
      insert(:integration,
        integration: "crelate",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "external_api_key" => "sx9fgdr8c7gn4tdpyds1fmfybo",
          "whippy_api_key" => "test_whippy_api_key"
        },
        settings: %{
          "sync_custom_data" => false,
          "only_active_assignments" => false,
          "send_contacts_to_external_integrations" => true,
          "crelate_messages_action_id" => "1a8fb229-16a1-46ec-00b7-cade951edd08",
          "use_production_url" => false
        }
      )

    # The tests of talent_activities assume the users and talents (contacts) have already been synced
    insert(:user, integration: integration, external_user_id: "12245", whippy_user_id: "1")

    insert(:contact,
      integration: integration,
      external_contact_id: "450bf96e-eb32-42bc-d11f-6ce89035dd08",
      name: "John Doe",
      whippy_contact_id: "24e6057f-55d9-44e6-b164-29e0882c8ad2",
      external_organization_id: "test_external_organization_id",
      whippy_organization_id: "test_whippy_organization_id"
    )

    insert(:contact,
      phone: "+17139723626",
      integration: integration,
      external_contact_id: "321",
      whippy_contact_id: "fb8db6e1-5c11-44d4-b623-8df92e8e25ce",
      external_organization_id: "test_external_organization_id",
      whippy_organization_id: "test_whippy_organization_id"
    )

    %{integration: integration}
  end

  describe "process/1 for full sync" do
    test "pulls messages from Whippy and saves them as activities then pushes them to Crelate", %{
      integration: integration
    } do
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today)
      {:ok, list_users_result} = Fixtures.WhippyClient.list_users_fixture()

      # Perform pull_messages_from_whippy job and assert that the messages are saved as activities
      with_mock(HTTPoison, [],
        request: fn _method, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/users" -> {:ok, list_users_result}
            "http://localhost:4000/v1/conversations" -> {:ok, list_conversations_result}
            _ -> {:ok, get_conversation_result}
          end
        end
      ) do
        assert :ok ==
                 perform_job(Activities, %{
                   "type" => "pull_messages_from_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform push_messages_to_crelate job and assert that the messages are pushed to crelate
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.get_channel_fixture() end,
        post: fn _url, body, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes = [
            "Hi there, you haven't answered back.<br/><br/>",
            "Hello again<br/><br/>",
            "Wanted to know if would you like to apply for forklift driver?<br/><br/>",
            "Hello?<br/><br/>",
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=7b80e85b-27cd-4c82-af10-5849ece72258"
          ]

          display_content = decoded_body["entity"]["Display"]

          normalized_notes =
            Enum.map(expected_notes, fn note -> String.replace(note, "<br/><br/>", "") end)

          Enum.each(normalized_notes, fn note ->
            assert String.contains?(display_content, note), "Missing note: #{note}"
          end)

          Fixtures.CrelateClient.create_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(Activities, %{
                   "type" => "push_messages_to_crelate",
                   "integration_id" => integration.id
                 })

        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.external_activity_id != nil end)
      end
    end
  end

  describe "process/1 for daily sync" do
    test "pulls messages from Whippy for specific date range and then pushes them as activities to Crelate", %{
      integration: integration
    } do
      today = DateTime.utc_now()
      yesterday = DateTime.add(today, -1, :day)

      today_iso = Date.to_string(today)
      _two_days_ago_iso = yesterday |> DateTime.add(-1, :day) |> Date.to_string()

      # Temporarily we are overfetching messages from Whippy up to 4 days ago,
      # we will change this to up to 2 days ago in the future.
      # When that happens, we will need to update the test to use the two_days_ago_iso variable.
      four_days_ago_iso = yesterday |> DateTime.add(-3, :day) |> Date.to_string()

      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today)
      {:ok, list_users_result} = Fixtures.WhippyClient.list_users_fixture()

      # Perform daily_pull_messages_from_whippy job and assert that the messages are saved as activities
      with_mock(HTTPoison, [],
        request: fn _method, url, _body, _header, opts ->
          case url do
            "http://localhost:4000/v1/users" ->
              {:ok, list_users_result}

            # Assert that the correct date range is passed to the list_conversations endpoint
            "http://localhost:4000/v1/conversations" ->
              assert get_in(opts, [:params, :"last_message_date[before]"]) =~ today_iso
              assert get_in(opts, [:params, :"last_message_date[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

              {:ok, list_conversations_result}

            # Assert that the correct date range is passed to the get_conversation endpoint
            _ ->
              assert get_in(opts, [:params, :"messages[before]"]) =~ today_iso
              assert get_in(opts, [:params, :"messages[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

              {:ok, get_conversation_result}
          end
        end
      ) do
        :ok =
          perform_job(Activities, %{
            "day" => today_iso,
            "integration_id" => integration.id,
            "type" => "daily_pull_messages_from_whippy"
          })

        # Assert that the Whippy messages are saved as activities
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform daily_push_messages_to_crelate job and assert that the messages are pushed to crelate
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.get_channel_fixture() end,
        post: fn _url, body, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes = [
            "Hi there, you haven't answered back.<br/><br/>",
            "Hello again<br/><br/>",
            "Wanted to know if would you like to apply for forklift driver?<br/><br/>",
            "Hello?<br/><br/>",
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=7b80e85b-27cd-4c82-af10-5849ece72258"
          ]

          display_content =
            decoded_body["entity"]["Display"]
            |> String.replace(~r/<\/?[^>]+>/, "")
            |> String.replace(~r/\s+/, " ")
            |> String.trim()

          modified_notes =
            Enum.map(expected_notes, fn note ->
              note
              |> String.replace(~r/<\/?[^>]+>/, "")
              |> String.replace(~r/\s+/, " ")
              |> String.trim()
            end)

          assert String.contains?(display_content, modified_notes)

          Fixtures.CrelateClient.create_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(Activities, %{
                   "day" => today_iso,
                   "integration_id" => integration.id,
                   "type" => "daily_push_messages_to_crelate"
                 })

        # Assert that the Activities are updated with the correct external_activity_id
        assert [%Activity{} | _] = activities = Repo.all(Activity)

        assert Enum.all?(activities, fn activity ->
                 activity.external_activity_id == "767a9de7-7349-48a2-1ec3-03d1d33bdd08"
               end)
      end
    end
  end
end
