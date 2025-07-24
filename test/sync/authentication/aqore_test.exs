defmodule Sync.Authentication.AqoreTest do
  use SyncWeb.ConnCase
  use ExUnit.Case

  import Mock
  import Sync.Factory

  alias Sync.Authentication.Aqore

  @client_request_limit "200"

  setup do
    access_token = create_access_token(1_722_935_391)

    integration =
      insert(:integration,
        integration: "aqore",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "requests_made" => 10,
          "access_token" => access_token,
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "whippy_api_key" => "test_whippy_api_key",
          "base_api_url" => "https://www.aqore.com"
        }
      )

    %{integration: integration}
  end

  describe "get_integration_details/1" do
    test "returns existing token when not expired and under request limit", %{
      integration: integration
    } do
      access_token = create_access_token(1_722_935_391)

      with_mock(HTTPoison, [],
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"access_token": "#{access_token}"})}}
        end
      ) do
        {:ok, %{"access_token" => output}} = Aqore.get_integration_details(integration)
        assert access_token == output
      end
    end

    test "generates new token when existing token is expired", %{integration: integration} do
      access_token = create_access_token(1)

      with_mock(HTTPoison, [],
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"access_token": "#{access_token}"})}}
        end
      ) do
        assert {:ok, %{"access_token" => access_token, "base_api_url" => "https://www.aqore.com"}} ==
                 Aqore.get_integration_details(integration)
      end
    end

    test "generates new token when request limit is reached", %{integration: integration} do
      access_token = create_access_token(9_999_999_999)

      with_mock(HTTPoison, [],
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"access_token": "#{access_token}"})}}
        end
      ) do
        assert {:ok, %{"access_token" => access_token, "base_api_url" => "https://www.aqore.com"}} ==
                 Aqore.get_integration_details(integration)
      end
    end
  end

  describe "get_integration_details/1 base_api_url" do
    test "returns the map containing url and access token", %{
      integration: integration
    } do
      access_token = create_access_token(1_722_935_391)
      url = integration.authentication["base_api_url"]

      with_mock(HTTPoison, [],
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"access_token": "#{access_token}"})}}
        end
      ) do
        {:ok, %{"base_api_url" => base_api_url}} = Aqore.get_integration_details(integration)
        assert base_api_url == url
      end
    end
  end

  describe "generate_access_token/1" do
    test "successfully generates a new access token", %{integration: integration} do
      current_time = DateTime.to_unix(DateTime.utc_now())
      access_token = create_access_token(current_time + 1)

      with_mock HTTPoison,
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"access_token": "#{access_token}"})}}
        end do
        assert {:ok, access_token} == Aqore.generate_access_token(integration)
      end
    end

    test "returns error when API request fails", %{integration: integration} do
      with_mock(HTTPoison,
        post: fn _, _, _ ->
          {:error, %HTTPoison.Error{reason: "network error"}}
        end
      ) do
        assert {:error, "network error"} == Aqore.generate_access_token(integration)
      end
    end
  end

  describe "jwt_decode/1" do
    test "correctly decodes a JWT token" do
      token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MjI5MzUzOTF9.signature"
      decoded = Aqore.jwt_decode(token)
      assert %{"exp" => 1_722_935_391} == decoded
    end
  end

  describe "expired?/1" do
    test "returns true for expired timestamp" do
      expired_timestamp = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix()
      assert Aqore.expired?(expired_timestamp)
    end

    test "returns false for non-expired timestamp" do
      future_timestamp = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
      refute Aqore.expired?(future_timestamp)
    end

    test "handles string timestamps" do
      expired_timestamp =
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix() |> to_string()

      future_timestamp =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix() |> to_string()

      assert Aqore.expired?(expired_timestamp)
      refute Aqore.expired?(future_timestamp)
    end

    test "returns true for invalid timestamp format" do
      assert Aqore.expired?("invalid_timestamp")
    end
  end

  ######################
  ## Helper functions ##
  ######################

  # This function creates a JWT token with the given expiry time
  # These variables are used to handle rate limiting and when to refresh the access token
  defp create_access_token(expiry) do
    payload =
      Base.encode64(%{"exp" => expiry, "client_requestLimit" => @client_request_limit} |> Jason.encode!() |> to_string())

    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.#{payload}.signature"
  end
end
