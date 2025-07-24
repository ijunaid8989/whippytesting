defmodule Sync.Clients.LoxoTest do
  use ExUnit.Case, async: false

  import Mock
  import Sync.Fixtures.LoxoClient

  alias Sync.Clients.Loxo

  require Logger

  @api_key "api_key"
  @person_id 166_640_410
  @agency_slug "agency_slug"

  @person_events_endpoint "https://app.loxo.co/api/agency_slug/person_events"
  @people_endpoint "https://app.loxo.co/api/agency_slug/people"
  @users_endpoint "https://app.loxo.co/api/agency_slug/users"

  # We log an error when we get a non-success status code
  # and this tag captures the log so it does not clutter the test output
  @moduletag capture_log: true

  describe "list_activity_types/2" do
    test "makes a request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _opts ->
          assert url == "https://app.loxo.co/api/agency_slug/activity_types"

          list_activity_types_fixture()
        end do
        Loxo.list_activity_types("api_key", "agency_slug")
      end
    end

    test "returns a list of parsed activity types" do
      with_mock HTTPoison, get: fn _api_key, _agency_slug -> list_activity_types_fixture() end do
        assert {:ok,
                [
                  %{name: "Marked as Maybe", activity_type_id: 1_676_385},
                  %{name: "Marked as Yes", activity_type_id: 1_676_386},
                  %{name: "Longlisted", activity_type_id: 1_676_387},
                  %{name: "Note Update", activity_type_id: 1_676_388},
                  %{name: "Sent Automated Email", activity_type_id: 1_676_389}
                ]} = Loxo.list_activity_types("api_key", "agency_slug")
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 500}}

      with_mock HTTPoison, get: fn _api_key, _agency_slug -> error end do
        assert {:error, ^error} = Loxo.list_activity_types("api_key", "agency_slug")
      end
    end
  end

  describe "create_person_event/3" do
    test "makes a request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _payload, _headers, _opts ->
          assert url == @person_events_endpoint
          create_person_event_fixture()
        end do
        Loxo.create_person_event(@api_key, @agency_slug, %{})
      end
    end

    test "returns the created person event - ensure it is of model type PersonEvent" do
      with_mock HTTPoison,
        post: fn _url, _payload, _headers, _opts ->
          create_person_event_fixture()
        end do
        response = Loxo.create_person_event(@api_key, @agency_slug, %{})

        assert {:ok,
                %Sync.Clients.Loxo.Model.PersonEvent{
                  id: person_event_id,
                  notes: activity_message,
                  person_id: person_id
                }} = response

        assert person_event_id == 822_112_904

        assert activity_message ==
                 "Crafting vivid tapestries that reflect the kaleidoscope of human imagination"

        assert person_id == @person_id
      end
    end
  end

  describe "list_people/3" do
    test "makes a request to the correct endpoint without scroll_id" do
      with_mock HTTPoison,
        get: fn url, _opts ->
          assert url == @people_endpoint
          list_people_fixture()
        end do
        Loxo.list_people("api_key", "agency_slug")
      end
    end

    test "makes a request to the correct endpoint with scroll_id" do
      with_mock HTTPoison,
        get: fn url, _opts ->
          assert url == @people_endpoint <> "?scroll_id=test_scroll_id"
          list_people_fixture()
        end do
        Loxo.list_people("api_key", "agency_slug", "test_scroll_id")
      end
    end

    test "returns a list of people and a scroll_id" do
      with_mock HTTPoison,
        get: fn _url, _opts ->
          list_people_fixture()
        end do
        assert {:ok, people, scroll_id} = Loxo.list_people("api_key", "agency_slug")
        assert length(people) == 1
        # set to nil to prevent pagination
        assert scroll_id == nil
      end
    end

    test "returns an error tuple if the request fails" do
      with_mock HTTPoison, get: fn _url, _opts -> nil end do
        assert {:error, nil} = Loxo.list_people("api_key", "agency_slug")
      end
    end
  end

  describe "create_person/4" do
    test "makes a request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _payload, _headers, _opts ->
          assert url == @people_endpoint
          create_person_fixture()
        end do
        Loxo.create_person(%{name: "John Doe"}, "api_key", "agency_slug")
      end
    end

    test "returns the created person" do
      with_mock HTTPoison,
        post: fn _url, _payload, _headers, _opts ->
          create_person_fixture()
        end do
        response = Loxo.create_person(%{name: "John Doe"}, "api_key", "agency_slug")
        assert {:ok, %{name: name}} = response
        assert name == "John Doe"
      end
    end
  end

  describe "list_users/2" do
    test "makes a request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _opts ->
          assert url == @users_endpoint
          list_users_fixture()
        end do
        Loxo.list_users("api_key", "agency_slug")
      end
    end

    test "returns a list of users" do
      with_mock HTTPoison,
        get: fn _url, _opts ->
          list_users_fixture()
        end do
        assert {:ok, users} = Loxo.list_users("api_key", "agency_slug")
        assert length(users) == 1
      end
    end

    test "ensure response is structured for Whippy contact - it is converted from Loxo structure to Whippy structure" do
      with_mock HTTPoison,
        get: fn _url, _opts ->
          list_users_fixture()
        end do
        assert {:ok, users} = Loxo.list_users("api_key", "agency_slug")
        assert length(users) == 1

        %{
          first_name: first_name,
          last_name: last_name,
          email: email,
          external_user_id: external_user_id
        } = Enum.at(users, 0)

        assert first_name == "Timothy"
        assert last_name == "Cooked"
        assert email == "tim@apple.com"
        assert external_user_id == "150101"
      end
    end

    test "returns an error tuple if the request fails" do
      with_mock HTTPoison, get: fn _url, _opts -> nil end do
        assert {:error, nil} = Loxo.list_users("api_key", "agency_slug")
      end
    end
  end
end
