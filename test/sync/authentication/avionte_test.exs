defmodule Sync.Authentication.AvionteTest do
  use SyncWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory

  alias Sync.Authentication.Avionte

  @access_token "eyJ0eKSiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6ImEzck1VZ01Gdjl0UGNsTGE2eUYzekFrZnF1RSIsImtpZCI6ImEzck1VZ01Gdjl0UGNsTGE2eUYzekFrZnF1RSJ9.eyJpc3PiOiJodHRwczovL2lkLmF2aW9udGUuY29tLyIsImF1ZCI6Imh0dHBzOi8vaWQuYXZpb250ZS5jb20vcmVzb3VyY2WzIiwiZXhwIjoxNzE1MTc1NTYzLCJuYmYiOjE3MTUxNzE5NjMsImNsaWVudF9pZCI6InBhcnRuZXIuYXBpLndoaXBweSIsImF2aW9udGUudGVuYW50IjoiYXBpdGVzdCIsInNjb3BlIjoiYXZpb250ZS5hYXJvLmNvbXBhc2ludGVncmF0aW9uc2VydmljZSJ9.mOHVkqwqCAG8PusoJWwe021AmVJK3d4hze3hBdv1iI1mYx3wOeLJxWOZyK1LarPkTS8vpr89e5lgfn060o8iBeK_U0X1rbHGrjkJZ5zRlmv_VLFelD9JY4-O49voORFNajZ7q5Q5lzg5zniPEUbEXVONKj3ZLvL1kBr9M6NFOKq4nKLx3ixyS2xuY1W9PESg6dD4I8C5Zpu1OR-mCbmjn6DmpwucHRUyLZCE3eGcXk6sj9MXPnjqzfZa3znQqy4ZayhJkueATnHK8BKKTRa-KhttyS14fCfVNjCAkZWSISSjThsfmrGU6XsmVDzH-fvBn_tNX3yOC-mcnvhGM2Sqiw"

  describe "get_or_regenerate_access_token/1" do
    setup do
      integration =
        insert(:integration,
          integration: "avionte",
          client: :avionte,
          whippy_organization_id: "test_whippy_organization_id",
          authentication: %{
            "external_api_key" => "test_api_key",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret",
            "scope" => "test_scope",
            "grant_type" => "client_credentials",
            "fallback_external_user_id" => "12245",
            "tenant" => "whippy",
            "whippy_api_key" => "test_whippy_api_key"
          }
        )

      %{integration: integration}
    end

    test "returns access token after making a request to Avionte", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:success)) do
        assert {:ok, @access_token, _integration} = Avionte.get_or_regenerate_access_token(integration)
        assert called(HTTPoison.post(:_, :_, :_))
      end
    end

    @tag capture_log: true
    test "returns :error if access token could not be retrieved due to missing credentials", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:error)) do
        assert {:error, _error} = Avionte.get_or_regenerate_access_token(integration)
        assert called(HTTPoison.post(:_, :_, :_))
      end
    end

    test "returns :error if authentication is missing required keys" do
      integration = insert(:integration, %{authentication: %{}})

      capture_log(fn ->
        assert {:error, _error} = Avionte.get_or_regenerate_access_token(integration)
      end) =~ "Missing authentication credentials. client_id, client_secret, and api_key are required."
    end

    test "returns the access token from the integration record if it is not expired" do
      integration =
        insert(:integration, %{
          authentication: %{
            "access_token" => "existing_valid_token",
            "token_expires_in" => DateTime.to_unix(DateTime.utc_now()) + 600
          }
        })

      assert {:ok, "existing_valid_token", _integration} = Avionte.get_or_regenerate_access_token(integration)
    end

    test "renews and returns the access token if the token is expired", %{integration: integration} do
      expired_authentication = %{
        "access_token" => "existing_expired_token",
        "token_expires_in" => DateTime.to_unix(DateTime.utc_now()) - 600
      }

      integration = %{integration | authentication: Map.merge(integration.authentication, expired_authentication)}

      with_mock(HTTPoison, [], httpoison_mock(:success)) do
        assert {:ok, @access_token, _integration} = Avionte.get_or_regenerate_access_token(integration)
        assert called(HTTPoison.post(:_, :_, :_))
      end
    end
  end

  defp httpoison_mock(status) do
    [
      post: fn _url, _params, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: status_code(status),
           body: Jason.encode!(access_token_response(status))
         }}
      end
    ]
  end

  defp access_token_response(:success) do
    %{
      "access_token" => @access_token,
      "expires_in" => 3600,
      "token_type" => "Bearer"
    }
  end

  defp access_token_response(:error) do
    # Possible errors are: "unsupported_grant_type", "invalid_scope", "invalid_client"
    %{"error" => "invalid_client"}
  end

  defp status_code(:success), do: 200
  defp status_code(:error), do: 400
end
