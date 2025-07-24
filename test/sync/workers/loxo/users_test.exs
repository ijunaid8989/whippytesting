defmodule Sync.Workers.Loxo.UsersTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory

  alias Sync.Fixtures
  alias Sync.Workers.Loxo.Users

  setup do
    integration =
      insert(:integration,
        integration: "loxo",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "external_api_key" => "test_loxo_api_key",
          "whippy_api_key" => "test_whippy_api_key",
          "agency_slug" => "test_agency_slug"
        }
      )

    %{integration: integration}
  end

  describe "process/1" do
    test "pulls users from Loxo and processes them", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:loxo_pull_users)) do
        log =
          capture_log(fn ->
            assert :ok ==
                     perform_job(Users, %{
                       "type" => "pull_users_from_loxo",
                       "integration_id" => integration.id
                     })
          end)

        # Assertions for the expected behavior after pulling users from Loxo
        assert log =~
                 "Pulling users from Loxo for Loxo integration #{integration.id}"
      end
    end

    test "pulls users from Whippy and processes them", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_pull_users)) do
        log =
          capture_log(fn ->
            assert :ok ==
                     perform_job(Users, %{
                       "type" => "pull_users_from_whippy",
                       "integration_id" => integration.id
                     })
          end)

        # Assertions for the expected behavior after pulling users from Whippy
        assert log =~
                 "Pulling users from Whippy for Loxo integration #{integration.id}"
      end
    end
  end

  defp httpoison_mock(:loxo_pull_users) do
    [
      get: fn _url, _headers -> Fixtures.LoxoClient.list_users_fixture() end
    ]
  end

  defp httpoison_mock(:whippy_pull_users) do
    [
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_users_fixture() end
    ]
  end
end
