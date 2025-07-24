defmodule Sync.Workers.Avionte.UsersTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Fixtures
  alias Sync.Integrations.User
  alias Sync.Repo
  alias Sync.Workers.Avionte.Users

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

    %{integration: integration}
  end

  describe "process/1" do
    test "pulls users from Avionte and saves them as users", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:avionte)) do
        assert [] == Repo.all(User)

        assert :ok == perform_job(Users, %{"type" => "pull_users_from_avionte", "integration_id" => integration.id})

        assert [%User{} | _] = users = Repo.all(User)
        assert Enum.all?(users, fn user -> user.external_organization_id == "test_external_organization_id" end)
      end
    end

    test "pulls users from Whippy and saves them as users", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy)) do
        assert [] == Repo.all(User)

        assert :ok == perform_job(Users, %{"type" => "pull_users_from_whippy", "integration_id" => integration.id})

        assert [%User{} | _] = users = Repo.all(User)
        assert Enum.all?(users, fn user -> user.whippy_organization_id == "test_whippy_organization_id" end)
      end
    end

    test "pulling users from Avionte does not raise an exception if the user with the same email is in the database", %{
      integration: integration
    } do
      insert(:user, email: "Yogen.Bista@avionte.com", integration: integration)

      with_mock(HTTPoison, [], httpoison_mock(:avionte)) do
        assert :ok == perform_job(Users, %{"type" => "pull_users_from_avionte", "integration_id" => integration.id})
      end
    end

    test "pulling users from Whippy does not raise an exception if the user with the same email is in the database", %{
      integration: integration
    } do
      insert(:user, email: "test@example.com", integration: integration)

      with_mock(HTTPoison, [], httpoison_mock(:whippy)) do
        assert :ok == perform_job(Users, %{"type" => "pull_users_from_whippy", "integration_id" => integration.id})
      end
    end
  end

  defp httpoison_mock(:avionte) do
    [
      post: fn _url, _params, _headers, _opts -> Fixtures.AvionteClient.list_users_fixture() end,
      get: fn _url, _headers, _opts -> Fixtures.AvionteClient.list_users_fixture() end
    ]
  end

  defp httpoison_mock(:whippy) do
    [
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_users_fixture() end
    ]
  end
end
