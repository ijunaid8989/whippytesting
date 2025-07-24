defmodule Sync.Workers.Avionte.BranchesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Channels.Channel
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Avionte.Branches

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
    test "pulls branches from Avionte and saves them as branches", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock()) do
        assert [] == Repo.all(Channel)

        assert :ok == perform_job(Branches, %{"type" => "pull_branches_from_avionte", "integration_id" => integration.id})

        assert [%Channel{} | _] = branches = Repo.all(Channel)
        assert Enum.all?(branches, fn user -> user.external_organization_id == "test_external_organization_id" end)
      end
    end
  end

  defp httpoison_mock do
    [
      get: fn _url, _headers, _opts -> Fixtures.AvionteClient.list_branches_fixture() end
    ]
  end
end
