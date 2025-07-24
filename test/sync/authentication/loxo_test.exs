defmodule Sync.Authentication.LoxoTest do
  use ExUnit.Case

  alias Sync.Authentication.Loxo
  alias Sync.Integrations.Integration

  describe "get_api_key/1" do
    test "returns the API key if present in the authentication field" do
      integration = %Integration{authentication: %{"external_api_key" => "test_api_key"}}
      assert {:ok, "test_api_key"} = Loxo.get_api_key(integration)
    end

    test "returns an error if the API key is missing" do
      integration = %Integration{authentication: %{}}
      assert {:error, "Invalid or missing Loxo API key"} = Loxo.get_api_key(integration)
    end

    test "returns an error if the authentication field is not a map" do
      integration = %Integration{authentication: nil}
      assert {:error, "Invalid or missing Loxo API key"} = Loxo.get_api_key(integration)
    end
  end

  describe "get_agency_slug/1" do
    test "returns the agency slug if present in the authentication field" do
      integration = %Integration{authentication: %{"agency_slug" => "test_agency_slug"}}
      assert {:ok, "test_agency_slug"} = Loxo.get_agency_slug(integration)
    end

    test "returns an error if the agency slug is missing" do
      integration = %Integration{authentication: %{}}
      assert {:error, "Invalid or missing Loxo agency slug"} = Loxo.get_agency_slug(integration)
    end

    test "returns an error if the authentication field is not a map" do
      integration = %Integration{authentication: nil}
      assert {:error, "Invalid or missing Loxo agency slug"} = Loxo.get_agency_slug(integration)
    end
  end
end
