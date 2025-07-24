defmodule Sync.Workers.Tempworks.MessagesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Activities.Activity
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Tempworks.Messages

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
          "acr_values" => "tenant:twtest pid:uuid"
        },
        settings: %{
          "use_advance_search" => false
        }
      )

    %{integration: integration}
  end

  describe "process/1 for daily sync" do
    test "pulls messages from Whippy for specific date range and then pushes them as messages to Tempworks", %{
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

      {:ok, contacts_list} = Fixtures.WhippyClient.get_contact_fixture()
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversation_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today)
      {:ok, list_users_result} = Fixtures.WhippyClient.list_users_fixture()

      # Perform daily_pull_messages_from_whippy job and assert that the messages are saved as activities
      with_mocks([
        {HTTPoison, [],
         request: fn _method, url, _body, _header, opts ->
           case url do
             "http://localhost:4000/v1/users" ->
               {:ok, list_users_result}

             # Assert that the correct date range is passed to the list_conversations endpoint
             "http://localhost:4000/v1/conversations" ->
               assert get_in(opts, [:params, :"last_message_date[before]"]) =~ today_iso
               assert get_in(opts, [:params, :"last_message_date[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

               {:ok, list_conversations_result}

             "http://localhost:4000/v1/contacts/24e6057f-55d9-44e6-b164-29e0882c8ad2" ->
               {:ok, contacts_list}

             # Assert that the correct date range is passed to the get_conversation endpoint
             _ ->
               assert get_in(opts, [:params, :"messages[before]"]) =~ today_iso
               assert get_in(opts, [:params, :"messages[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

               {:ok, get_conversation_result}
           end
         end},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()}
      ]) do
        :ok =
          perform_job(Messages, %{
            "type" => "daily_pull_messages_from_whippy",
            "integration_id" => integration.id,
            "day" => today_iso
          })

        # Assert that the Whippy messages are saved as activities
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform daily_push_messages_to_tempworks job and assert that the messages are pushed to tempworks
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

          Fixtures.TempworksClient.create_message_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(Messages, %{
                   "type" => "frequently_push_messages_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })

        # Assert that the Activities are updated with the correct external_activity_id
        assert [%Activity{} | _] = Repo.all(Activity)
      end
    end
  end

  describe "process/1 for message sync" do
    test "pulls messages from Whippy for specific date range and then pushes them as messages to Tempworks thorugh message sync",
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

      {:ok, contacts_list} = Fixtures.WhippyClient.get_contact_fixture()
      {:ok, list_conversations_result} = Fixtures.WhippyClient.list_conversation_fixture()
      {:ok, get_conversation_result} = Fixtures.WhippyClient.get_conversation_fixture(:messages_from_today)
      {:ok, list_users_result} = Fixtures.WhippyClient.list_users_fixture()

      # Perform daily_pull_messages_from_whippy job and assert that the messages are saved as activities
      with_mocks([
        {HTTPoison, [],
         request: fn _method, url, _body, _header, opts ->
           case url do
             "http://localhost:4000/v1/users" ->
               {:ok, list_users_result}

             # Assert that the correct date range is passed to the list_conversations endpoint
             "http://localhost:4000/v1/conversations" ->
               assert get_in(opts, [:params, :"last_message_date[before]"]) =~ today_iso
               assert get_in(opts, [:params, :"last_message_date[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

               {:ok, list_conversations_result}

             "http://localhost:4000/v1/contacts/24e6057f-55d9-44e6-b164-29e0882c8ad2" ->
               {:ok, contacts_list}

             # Assert that the correct date range is passed to the get_conversation endpoint
             _ ->
               assert get_in(opts, [:params, :"messages[before]"]) =~ today_iso
               assert get_in(opts, [:params, :"messages[after]"]) =~ four_days_ago_iso <> "T12:00:00Z"

               {:ok, get_conversation_result}
           end
         end},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()}
      ]) do
        :ok =
          perform_job(Messages, %{
            "type" => "frequently_pull_messages_from_whippy",
            "integration_id" => integration.id,
            "day" => today_iso
          })

        # Assert that the Whippy messages are saved as activities
        assert [%Activity{} | _] = activities = Repo.all(Activity)
        assert Enum.all?(activities, fn activity -> activity.whippy_organization_id == "test_whippy_organization_id" end)
        assert Enum.count(activities) == Enum.count(Jason.decode!(get_conversation_result.body)["data"]["messages"])
      end

      # Perform daily_push_messages_to_tempworks job and assert that the messages are pushed to tempworks
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

          Fixtures.TempworksClient.create_message_fixture()
        end
      ) do
        assert :ok ==
                 perform_job(Messages, %{
                   "type" => "frequently_push_messages_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => today_iso
                 })

        # Assert that the Activities are updated with the correct external_activity_id
        assert [%Activity{} | _] = Repo.all(Activity)
      end
    end
  end

  def tempworks_client_universal_phone_mock do
    [
      get_employee_universal_phone: fn _, _ ->
        {:ok,
         [
           %Sync.Clients.Tempworks.Model.UniversalPhone{
             employeeId: "43760",
             firstName: "Magnet",
             lastName: "712",
             branchName: "WhippyDemoBranch",
             phoneNumber: "+141756480961",
             phoneType: "Phone",
             isAssigned: false,
             isActive: true,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           }
         ]}
      end
    ]
  end
end
