defmodule Sync.Clients.AqoreTest do
  use ExUnit.Case, async: false

  import Mock

  alias Sync.Clients.Aqore.Resources.AqoreContacts
  alias Sync.Clients.Aqore.Resources.Candidates
  alias Sync.Clients.Aqore.Resources.Comments
  alias Sync.Clients.Aqore.Resources.Users
  alias Sync.Fixtures.AqoreClient
  alias Sync.Utils.Http.Retry

  # Capturing error logs printed during tests, in order to not clutter the output
  @moduletag capture_log: true
  @aqore_map %{"base_api_url" => "www.google.com", "access_token" => "some_random_token"}

  setup do
    :ok
  end

  describe "list_candidates/3" do
    setup_with_mocks([
      {HTTPoison, [:passthrough], [post: fn _url, _body, _headers, _opts -> AqoreClient.list_candidates_fixture() end]},
      {Retry, [], [request: fn function, _opts -> function.() end]}
    ]) do
      :ok
    end

    test "returns a list of candidates on successful response" do
      {:ok, candidates} = Candidates.list_candidates(@aqore_map, 10, 0, :full_sync)
      assert length(candidates) == 1
      first_candidate = hd(candidates)
      assert first_candidate.external_contact_id == "1"
      assert first_candidate.external_contact.firstName == "Paul"
      assert first_candidate.external_contact.lastName == "Clements"
    end

    test "returns an empty list when no candidates are found" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_candidates_empty_fixture() end do
        {:ok, candidates} = Candidates.list_candidates(@aqore_map, 10, 0, :full_sync)
        assert candidates == []
      end
    end

    test "returns an error tuple on unsuccessful response" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_candidates_error_fixture() end do
        assert {:error, :timeout} == Candidates.list_candidates(@aqore_map, 10, 0, :full_sync)
      end
    end

    test "returns a list of contacts on successful response" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_contact_fixture() end do
        {:ok, contacts} = AqoreContacts.list_aqore_contacts(@aqore_map, 10, 0, :full_sync)
        assert length(contacts) == 1
        first_contact = hd(contacts)
        assert first_contact.external_contact_id == "cont-1"
        assert first_contact.external_contact.firstName == "Paul"
        assert first_contact.external_contact.lastName == "Clements"
      end
    end

    test "handles limit and offset correctly in the payload" do
      with_mock HTTPoison,
        post: fn _url, body, _headers, _opts ->
          payload = Jason.decode!(body)
          assert payload["filters"]["page"] == 2
          assert payload["filters"]["size"] == 10
          {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!([])}}
        end do
        Candidates.list_candidates(@aqore_map, 10, 10, :full_sync)
      end
    end

    test "returns a partial list of candidates" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_candidates_partial_fixture() end do
        {:ok, candidates} = Candidates.list_candidates(@aqore_map, 10, 0, :full_sync)
        assert length(candidates) == 2

        assert Enum.any?(candidates, fn candidate ->
                 candidate.external_contact.firstName == "Jane"
               end)
      end
    end

    test "correctly maps candidate fields" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_candidates_partial_fixture() end do
        {:ok, candidates} = Candidates.list_candidates(@aqore_map, 10, 0, :full_sync)
        jane = Enum.find(candidates, fn c -> c.external_contact.firstName == "Jane" end)

        assert jane.name == "Jane Smith"
        assert jane.external_contact_id == "2"
        assert jane.external_contact.lastName == "Smith"
        assert jane.external_contact.title == "Project Manager"
        assert jane.external_contact.status == "Inactive"
        assert jane.external_contact.isActive == false
        assert jane.external_contact.address1 == "456 Elm St"
        assert jane.external_contact.city == "Gotham"
        assert jane.external_contact.state == "NJ"
        assert jane.external_contact.country == "USA"
        assert jane.external_contact.skills == ["Management", "Communication"]
        assert jane.external_organization_entity_type == "candidate"
      end
    end
  end

  describe "create_comment/2" do
    setup_with_mocks([
      {HTTPoison, [:passthrough], [post: fn _url, _body, _headers, _opts -> AqoreClient.create_comment_fixture() end]}
    ]) do
      :ok
    end

    test "returns parsed comment on successful response" do
      payload = %{
        "action" => "CommentTsk",
        "filters" => %{
          "source" => "Whippy",
          "subject" =>
            "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)",
          "comment" => "hello",
          "personId" => 1_000_339_808,
          "commentType" => "Message"
        }
      }

      {:ok, comment} = Comments.create_comment(@aqore_map, payload)

      assert comment.commentId == 3_087_177
      assert comment.success == true
    end

    test "returns parsed email comment on successful response" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.create_comment_fixture() end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" => "Whippy Emails",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Email"
          }
        }

        {:ok, comment} = Comments.create_comment(@aqore_map, payload)

        assert comment.commentId == 3_087_177
        assert comment.success == true
      end
    end

    test "returns parsed calls comment on successful response" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.create_comment_fixture() end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" => "Whippy Calls",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Call"
          }
        }

        {:ok, comment} = Comments.create_comment(@aqore_map, payload)

        assert comment.commentId == 3_087_177
        assert comment.success == true
      end
    end

    test "returns an error tuple on network error" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> {:error, %HTTPoison.Error{reason: :timeout}} end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" =>
              "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Message"
          }
        }

        assert {:error, :timeout} == Comments.create_comment(@aqore_map, payload)
      end
    end

    test "returns an error tuple on API error" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.create_comment_error_fixture() end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" =>
              "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Message"
          }
        }

        assert {:error, {:error, %HTTPoison.Response{status_code: 422, body: "{\"error\":\"unprocessable_entity\"}"}}} =
                 Comments.create_comment(@aqore_map, payload)
      end
    end

    test "sends correct payload and headers" do
      with_mock HTTPoison,
        post: fn _url, body, headers, _opts ->
          decoded_body = Jason.decode!(body)
          assert decoded_body["action"] == "CommentTsk"
          assert decoded_body["filters"]["source"] == "Whippy"

          assert decoded_body["filters"]["subject"] ==
                   "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)"

          assert decoded_body["filters"]["comment"] == "hello"
          assert decoded_body["filters"]["personId"] == 1_000_339_808
          assert decoded_body["filters"]["commentType"] == "Message"

          assert Enum.any?(headers, fn {key, value} ->
                   key == "Authorization" and String.contains?(value, "Bearer ")
                 end)

          AqoreClient.create_comment_fixture()
        end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" =>
              "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Message"
          }
        }

        Comments.create_comment(@aqore_map, payload)
      end
    end

    test "handles unexpected response format" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          AqoreClient.create_comment_unexpected_format_fixture()
        end do
        payload = %{
          "action" => "CommentTsk",
          "filters" => %{
            "source" => "Whippy",
            "subject" =>
              "Outbound call (13min) from +1 (111) 111-1111 (Agent Third Party) to +1 (222) 222-2222 (ALEXIS EUGENE PRESTON)",
            "comment" => "hello",
            "personId" => 1_000_339_808,
            "commentType" => "Message"
          }
        }

        assert {:error, %{"error" => "unprocessable_entity"}} ==
                 Comments.create_comment(@aqore_map, payload)
      end
    end
  end

  describe "list_users/3" do
    setup_with_mocks([
      {HTTPoison, [:passthrough], [post: fn _url, _body, _headers, _opts -> AqoreClient.list_users_fixture() end]},
      {Retry, [], [request: fn function, _opts -> function.() end]}
    ]) do
      :ok
    end

    test "returns a list of users on successful response" do
      {:ok, users} = Users.list_users(@aqore_map, 10, 0, :full_sync)
      assert length(users) == 2
      first_user = hd(users)

      assert first_user.first_name == "Paul"
      assert first_user.last_name == "Allen"
      assert first_user.external_user_id == "500000"
    end

    test "returns an empty list when no users are found" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_users_empty_fixture() end do
        {:ok, users} = Users.list_users(@aqore_map, 10, 0, :full_sync)
        assert users == []
      end
    end

    test "returns an error tuple on unsuccessful response" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_users_error_fixture() end do
        assert {:error, :timeout} == Users.list_users(@aqore_map, 10, 0, :full_sync)
      end
    end

    test "handles limit and offset correctly in the payload" do
      with_mock HTTPoison,
        post: fn _url, body, _headers, _opts ->
          payload = Jason.decode!(body)
          assert payload["filters"]["page"] == 2
          assert payload["filters"]["size"] == 10
          {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!([])}}
        end do
        Users.list_users(@aqore_map, 10, 10, :full_sync)
      end
    end

    test "correctly maps user fields" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts -> AqoreClient.list_users_fixture() end do
        {:ok, users} = Users.list_users(@aqore_map, 10, 0, :full_sync)
        jane = Enum.find(users, fn u -> u.first_name == "John" end)

        assert jane.last_name == "Doe"
        assert jane.external_user_id == "500001"
      end
    end
  end
end
