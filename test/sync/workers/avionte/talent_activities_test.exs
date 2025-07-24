defmodule Sync.Workers.Avionte.TalentActivitiesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Activities.Activity
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Avionte.TalentActivities

  setup do
    integration =
      insert(:integration,
        integration: "avionte",
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
          "tenant" => "apitest"
        }
      )

    # The tests of talent_activities assume the users and talents (contacts) have already been synced
    insert(:user, integration: integration, external_user_id: "12245", whippy_user_id: "1")

    insert(:contact,
      integration: integration,
      external_contact_id: "123",
      name: "John Doe",
      whippy_contact_id: "24e6057f-55d9-44e6-b164-29e0882c8ad2",
      external_organization_id: "test_external_organization_id",
      whippy_organization_id: "test_whippy_organization_id"
    )

    insert(:contact,
      phone: "+17139723626",
      integration: integration,
      external_contact_id: "contact-456",
      whippy_contact_id: "fb8db6e1-5c11-44d4-b623-8df92e8e25ce",
      external_organization_id: "test_external_organization_id",
      whippy_organization_id: "test_whippy_organization_id"
    )

    %{integration: integration}
  end

  describe "process/1 for full sync" do
    test "pulls messages from Whippy and saves them as activities then pushes them to Avionte", %{
      integration: integration
    } do
      today = DateTime.utc_now()
      today_iso = Date.to_string(today)
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today_and_before)
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
                 perform_job(TalentActivities, %{
                   "type" => "pull_messages_from_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform push_talent_activities_to_avionte job and assert that the messages are pushed to avionte
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/conversations/" <> _ -> Fixtures.WhippyClient.get_conversation_fixture()
            _ -> Fixtures.WhippyClient.get_channel_fixture()
          end
        end,
        post: fn _url, body, _headers, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes_one = [
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=b27ef765-dc2e-44e5-8eb2-59ab359f3b96<br/><br/>",
            "Are you still interested?<br/><br/>",
            "Yes this is us. How can we help?<br/><br/>",
            "I'm interested in a position <br/><br/>",
            "Hi is this staffing 101?<br/><br/>",
            "I saw your job post on some website.com.<br/><br/>"
          ]

          expected_notes_two = [
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=7b80e85b-27cd-4c82-af10-5849ece72258<br/><br/>",
            "Hi there, you haven't answered back.<br/><br/>",
            "Hello again<br/><br/>",
            "Wanted to know if would you like to apply for forklift driver?<br/><br/>",
            "Hello?<br/><br/>",
            "The job has been filled. <br/><br/>"
          ]

          expected_notes =
            case decoded_body["activityDate"] do
              "2024-06-09" <> _exact_time -> expected_notes_one
              ^today_iso <> _exact_time -> expected_notes_two
            end

          assert Enum.all?(expected_notes, fn note -> String.contains?(decoded_body["notes"], note) end)

          Fixtures.AvionteClient.create_talent_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "push_talent_activities_to_avionte",
                   "integration_id" => integration.id
                 })

        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.external_activity_id != nil end)
      end
    end

    test "correctly formats call messages before pushing them to avionte", %{integration: integration} do
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_of_type_call)

      # Perform pull_messages_from_whippy job and assert that the messages are saved as activities
      with_mock(HTTPoison, [],
        request: fn _method, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/conversations" -> {:ok, list_conversations_result}
            _ -> {:ok, get_conversation_result}
          end
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "pull_messages_from_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform push_talent_activities_to_avionte job and assert that the messages are pushed to avionte
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/conversations/" <> _ -> Fixtures.WhippyClient.get_conversation_fixture()
            _ -> Fixtures.WhippyClient.get_channel_fixture()
          end
        end,
        post: fn _url, body, _headers, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes =
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=07707015-04df-45a2-bfb3-c2fddabdfa4f<br/><br/>" <>
              "[John Doe] [Fri, 5 Jul 24 6:25 PM - IST] Agent: Hey, this is Alex at Express Employment can I have you full name please?<br/><br/>" <>
              "User: Uh, yes. John Kennedy.<br/><br/>" <>
              "Agent: Great, thanks John. Can you please provide me with your current address, including the city, state, and zip code?<br/><br/>" <>
              "User: Hey. Los Angeles, California 90025.<br/><br/>" <>
              "Agent: Thanks for that, John. What is your preferred method of contact - phone call, SMS, or email?<br/><br/>" <>
              "User: SMS, please.<br/><br/>" <>
              "Agent: How did you hear about Express Employment, John?<br/><br/>" <>
              "User: Alright. Thank you, Anad. Indeed, Job?<br/><br/>" <>
              "Agent: Got it, Anad. Can you tell me about your current situation? Are you currently working, and if so, where were you last employed?<br/><br/>" <>
              "User: No. I wasn't. I'm not working, and I've never employed before in my life.<br/><br/>" <>
              "Agent: Thanks for sharing that, Anad. Let's move on to your work history. Starting with your most recent <br/><br/>" <>
              "User: My name's my name's John.<br/><br/>" <>
              "Agent: Apologies for that, John. Let's start with your most recent work history. What was the company name?<br/><br/>" <>
              "User: McDonald's.<br/><br/>" <>
              "Agent: Where is the McDonald's located where you worked, John?<br/><br/>" <>
              "User: After going<br/><br/>" <>
              "Agent: I'm sorry, John, I didn't catch that. Can you please provide the location of the McDonald's where you worked?<br/><br/>" <>
              "User: I have to go now.<br/><br/>" <>
              "Agent: Sure, John. If you have to go, feel free to reach out to us when you're ready to continue. Have a great day!<br/><br/>" <>
              "User: Bye.<br/><br/>" <>
              "Agent: Goodbye, John. Take care!<br/><br/><br/><br/>"

          assert expected_notes == decoded_body["notes"]

          Fixtures.AvionteClient.create_talent_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "push_talent_activities_to_avionte",
                   "integration_id" => integration.id
                 })
      end
    end
  end

  describe "process/1 for daily sync" do
    test "pulls messages from Whippy for specific date range and then pushes them as activities to Avionte", %{
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
          perform_job(TalentActivities, %{
            "type" => "daily_pull_messages_from_whippy",
            "integration_id" => integration.id,
            "day" => today_iso
          })

        # Assert that the Whippy messages are saved as activities
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform daily_push_talent_activities_to_avionte job and assert that the messages are pushed to avionte
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/conversations/" <> _ -> Fixtures.WhippyClient.get_conversation_fixture()
            _ -> Fixtures.WhippyClient.get_channel_fixture()
          end
        end,
        post: fn _url, body, _headers, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes = [
            "Hi there, you haven't answered back.<br/><br/>",
            "Hello again<br/><br/>",
            "Wanted to know if would you like to apply for forklift driver?<br/><br/>",
            "Hello?<br/><br/>",
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/70c5c186-107e-4122-ba5c-24ac072f5898?message_id=7b80e85b-27cd-4c82-af10-5849ece72258"
          ]

          assert Enum.all?(expected_notes, fn note -> String.contains?(decoded_body["notes"], note) end)

          Fixtures.AvionteClient.create_talent_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "daily_push_talent_activities_to_avionte",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })

        # Assert that the Activities are updated with the correct external_activity_id
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.external_activity_id == "1447491470" end)
      end
    end

    test """
         when pushing messages to Avionte, provides a user ID derived from the messages of the conversation,
         as a user that logged the Activity
         """,
         %{integration: integration} do
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today)
      user = insert(:user, integration: integration, external_user_id: "54321", whippy_user_id: "2")

      today = DateTime.utc_now()
      today_iso = Date.to_string(today)

      with_mock(HTTPoison, [],
        request: fn _method, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/users" -> Fixtures.WhippyClient.list_users_fixture()
            "http://localhost:4000/v1/conversations" -> {:ok, list_conversations_result}
            _ -> {:ok, get_conversation_result}
          end
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "daily_pull_messages_from_whippy",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })
      end

      # Perform push_talent_activities_to_avionte job and assert that the messages are pushed to avionte
      # with the correct userId
      with_mock(HTTPoison, [],
        request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.get_channel_fixture() end,
        post: fn _url, body, _headers, _opts ->
          decoded_body = Jason.decode!(body)
          assert decoded_body["userId"] == String.to_integer(user.external_user_id)

          Fixtures.AvionteClient.create_talent_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "daily_push_talent_activities_to_avionte",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })
      end
    end

    test "pulls messages from Whippy for specific date range for avionte ocntacts and then pushes them as contact activities to Avionte",
         %{
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

      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_contact_conversations_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_contact_conversation_fixture(:messages_from_today)
      {:ok, list_users_result} = Fixtures.WhippyClient.list_contact_users_fixture()

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
          perform_job(TalentActivities, %{
            "type" => "daily_pull_messages_from_whippy",
            "integration_id" => integration.id,
            "day" => today_iso
          })

        # Assert that the Whippy messages are saved as activities
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform daily_push_talent_activities_to_avionte job and assert that the messages are pushed to avionte
      # in the correct format
      with_mock(HTTPoison, [],
        request: fn :get, url, _body, _header, _opts ->
          case url do
            "http://localhost:4000/v1/conversations/" <> _ -> Fixtures.WhippyClient.get_contact_conversation_fixture()
            _ -> Fixtures.WhippyClient.get_channel_fixture()
          end
        end,
        post: fn _url, body, _headers, _opts ->
          decoded_body = Jason.decode!(body)

          expected_notes = [
            "Hi there, you haven't answered back.<br/><br/>",
            "Hello again<br/><br/>",
            "Wanted to know if would you like to apply for forklift driver?<br/><br/>",
            "Hello?<br/><br/>",
            "https://app.whippy.co/organizations/test_whippy_organization_id/all/open/0ba4f325-6488-4d14-b926-49deb743881a?message_id=7b80e85b-27cd-4c82-af10-5849ece72258"
          ]

          assert Enum.all?(expected_notes, fn note -> String.contains?(decoded_body["notes"], note) end)

          Fixtures.AvionteClient.create_contact_activity_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(TalentActivities, %{
                   "type" => "daily_push_talent_activities_to_avionte",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })

        # Assert that the Activities are updated with the correct external_activity_id
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.external_activity_id == "1447491470" end)
      end
    end
  end
end
