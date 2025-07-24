defmodule Sync.Authentication.TempworksTest do
  use SyncWeb.ConnCase, async: false

  import Mock
  import Sync.Factory

  alias Sync.Authentication.Tempworks

  # Default OAuth URL for Tempworks authentication
  @default_oauth_url "https://login.ontempworks.com"
  # Endpoint for authorization
  @authorize_endpoint "/connect/authorize"
  # Default scopes required for OAuth permissions
  @default_scopes "assignment-write contact-write customer-write document-write employee-write hotlist-write message-write offline_access openid ordercandidate-write order-write profile universal-search"
  # Predefined ID token for testing purposes
  @default_id_token "eyJhbGciOiJSUzI1NiIsImtpZCI6IjVBRDc3MDFDMzA1MDVCNjUyNTU5OEIwMTNFQzU3RjU5MkJEMUFGQ0RSUzI1NiIsIng1dCI6Ild0ZHdIREJRVzJVbFdZc0JQc1ZfV1N2UnI4MCIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2xvZ2luLm9udGVtcHdvcmtzLmNvbSIsIm5iZiI6MTcxNDU1ODA2NywiaWF0IjoxNzE0NTU4MDY3LCJleHAiOjE3MTQ1NjE2NjcsImF1ZCI6IndoaXBweS1kZXYiLCJhbXIiOlsicHdkIl0sImF0X2hhc2giOiJHZm9mLXRtZHFHRnJiaWNBX3dZZG13Iiwic2lkIjoiQUJCMEY1OTA3NDMwNDM4RjI2NDc1M0M5MTY4RTJBMUIiLCJzdWIiOiJXaGlwcHkuRGVtbyIsImF1dGhfdGltZSI6MTcxNDQ4OTg0MywiaWRwIjoibG9jYWwiLCJyZXBuYW1lIjoiV2hpcHB5LkRlbW8iLCJzcmlkZW50IjoiMTA4MCIsIm5hbWUiOiJXaGlwcHkuRGVtbyIsInJvbGUiOiJTZXJ2aWNlUmVwIiwidGVuYW50IjoiV2hpcHB5IiwidHd1c2VyIjoiU2VydmljZVJlcCJ9.signature"

  # Generates a mock user authentication data for testing
  defp generate_user_authentication do
    %{
      "refresh_token" => Ecto.UUID.generate(),
      "id_token" => @default_id_token,
      "expires_in" => 3600,
      "token_type" => "Bearer"
    }
  end

  describe "get_user_authorization_url/2" do
    setup do
      integration = insert(:integration)
      user = insert(:user, integration: integration)
      %{user: user, integration: integration}
    end

    test "generates a valid authorization URL", %{
      integration: integration,
      user: user
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        {:ok, url} = Tempworks.get_user_authorization_url(integration, user.whippy_user_id)
        encoded_scopes = URI.encode_www_form(@default_scopes)
        assert String.contains?(url, @default_oauth_url <> @authorize_endpoint)
        assert String.contains?(url, "client_id=test_client_id")
        assert String.contains?(url, "scope=" <> encoded_scopes)
        assert String.contains?(url, "response_type=code")
        assert String.contains?(url, "code_challenge_method=S256")
      end
    end

    test "generates a valid authorization URL with setting overwrites", %{
      integration: integration,
      user: user
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        custom_base_url = "http://selfhosted.tempworks.whippy.ai"

        modified_changeset =
          Ecto.Changeset.change(integration, %{
            settings: %{"scopes" => Tempworks.default_scopes(), "base_url" => custom_base_url}
          })

        {:ok, updated_integration} = Sync.Repo.update(modified_changeset)

        {:ok, url} = Tempworks.get_user_authorization_url(updated_integration, user.whippy_user_id)
        assert String.contains?(url, custom_base_url <> @authorize_endpoint)
        assert String.contains?(url, "client_id=test_client_id")
        assert String.contains?(url, "scope=" <> URI.encode_www_form(Tempworks.default_scopes()))
        assert String.contains?(url, "response_type=code")
        assert String.contains?(url, "code_challenge_method=S256")
      end
    end

    test "with non-existent Whippy user returns error tuple", %{integration: integration} do
      custom_base_url = "http://selfhosted.tempworks.whippy.ai"

      modified_changeset =
        Ecto.Changeset.change(integration, %{
          settings: %{"scopes" => Tempworks.default_scopes(), "base_url" => custom_base_url}
        })

      {:ok, updated_integration} = Sync.Repo.update(modified_changeset)

      {:error, "User not found"} = Tempworks.get_user_authorization_url(updated_integration, 42)
      {:error, "User not found"} = Tempworks.get_user_authorization_url(updated_integration, "42")
    end

    test "handles an invalid integration" do
      assert {:error, _} = Tempworks.get_user_authorization_url(%{invalid: "input"}, "user_id")
    end
  end

  describe "refresh_user_token/1" do
    setup do
      integration = insert(:integration)
      user = insert(:user)
      %{user: user, integration: integration}
    end

    test "refreshes token successfully when valid refresh token is provided", %{
      user: user,
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        modified_user =
          Ecto.Changeset.change(user, %{
            integration_id: integration.id,
            authentication: generate_user_authentication()
          })

        {:ok, updated_user} = Sync.Repo.update(modified_user)

        {:ok, user} = Tempworks.refresh_user_token(updated_user)

        assert Map.has_key?(user.authentication, "id_token")
        assert Map.has_key?(user.authentication, "refresh_token")
        assert Map.has_key?(user.authentication, "expires_in")
        assert Map.has_key?(user.authentication, "token_type")
      end
    end

    test "returns error when invalid refresh token is provided", %{
      user: user,
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        updated_changeset =
          Ecto.Changeset.change(user, %{
            integration_id: integration.id,
            authentication: %{"refresh_token" => nil}
          })

        {:ok, updated_user} = Sync.Repo.update(updated_changeset)

        assert {:error, _error} = Tempworks.refresh_user_token(updated_user)
      end
    end
  end

  describe "exchange_code_for_token/2" do
    setup do
      integration = insert(:integration)
      user = insert(:user)
      %{user: user, integration: integration}
    end

    test "exchanges code for token successfully", %{
      user: user,
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        oauth_verification_code = Ecto.UUID.generate()

        updated_changeset =
          Ecto.Changeset.change(user, %{
            integration_id: integration.id,
            authentication: %{"code_verifier" => "verifier"}
          })

        {:ok, updated_user} = Sync.Repo.update(updated_changeset)

        {:ok, user} =
          Tempworks.exchange_code_for_token(updated_user.id, oauth_verification_code)

        assert Map.has_key?(user.authentication, "id_token")
        assert Map.has_key?(user.authentication, "refresh_token")
        assert Map.has_key?(user.authentication, "expires_in")
        assert Map.has_key?(user.authentication, "token_type")
      end
    end

    test "when there is no code present", %{
      user: user
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        assert {:error, _} = Tempworks.exchange_code_for_token(user.id, nil)
      end
    end
  end

  describe "get_or_regenerate_user_token/1" do
    setup do
      integration = insert(:integration)
      user = insert(:user)
      %{user: user, integration: integration}
    end

    test "returns user authentication when token is not expired", %{
      user: user,
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        # Set up user with a valid, non-expired token
        token_exp = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        id_token = generate_id_token(token_exp)

        updated_changeset =
          Ecto.Changeset.change(user, %{
            integration_id: integration.id,
            authentication: %{"id_token" => id_token}
          })

        {:ok, updated_user} = Sync.Repo.update(updated_changeset)

        {:ok, user} = Tempworks.get_or_regenerate_user_token(updated_user)

        assert user.authentication["id_token"] == id_token
      end
    end

    test "refreshes user authentication when token is expired", %{
      user: user,
      integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:success)}
      ]) do
        # Set up user with an expired token
        token_exp = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix()
        id_token = generate_id_token(token_exp)

        updated_changeset =
          Ecto.Changeset.change(user, %{
            integration_id: integration.id,
            authentication: %{
              "id_token" => id_token,
              "refresh_token" => "refresh_token"
            }
          })

        {:ok, updated_user} = Sync.Repo.update(updated_changeset)

        {:ok, user} = Tempworks.get_or_regenerate_user_token(updated_user)

        assert Map.has_key?(user.authentication, "id_token")
        assert Map.has_key?(user.authentication, "refresh_token")
      end
    end

    test "returns error for invalid user" do
      assert {:error, _} = Tempworks.get_or_regenerate_user_token(%{invalid: "user"})
    end

    defp generate_id_token(exp) do
      payload = %{
        "iss" => "https://login.ontempworks.com",
        "exp" => exp,
        "aud" => "test_client_id",
        "sub" => "test_user_id"
      }

      token =
        payload
        |> Jason.encode!()
        |> Base.url_encode64()

      "header." <> token <> ".signature"
    end
  end

  defp httpoison_mock(status) do
    [
      request: fn _method, _url, _payload, _headers, _options ->
        case status do
          :success ->
            {:ok, %HTTPoison.Response{body: Jason.encode!([]), status_code: 200}}
        end
      end,
      post: fn _url, _params, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(generate_user_authentication())
         }}
      end
    ]
  end
end
