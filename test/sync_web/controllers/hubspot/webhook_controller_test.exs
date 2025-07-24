defmodule SyncWeb.Hubspot.WebhookControllerTest do
  @moduledoc false

  use SyncWeb.ConnCase, async: true

  setup %{} do
    System.put_env("BASE_URL", "http://localhost:4001")
    System.put_env("HUBSPOT_CLIENT_SECRET", "FAKE VALID SECRET")

    on_exit(fn ->
      System.delete_env("BASE_URL")
      System.delete_env("HUBSPOT_CLIENT_SECRET")
    end)
  end

  describe "hubspot request validation" do
    test "Valid Hubspot signature and timestamp", %{conn: conn} do
      body = [%{"subscriptionType" => "fake", "objectTypeId" => "fake"}]
      timestamp = :os.system_time(:millisecond)
      request_uri = System.get_env("BASE_URL") <> "/webhooks/v1/hubspot"
      client_secret = System.get_env("HUBSPOT_CLIENT_SECRET")

      signature =
        :hmac
        |> :crypto.mac(:sha256, client_secret, "POST#{request_uri}#{Jason.encode!(body)}#{timestamp}")
        |> Base.encode64()

      conn =
        conn
        |> put_req_header("x-hubspot-signature-v3", signature)
        |> put_req_header("x-hubspot-request-timestamp", to_string(timestamp))
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/v1/hubspot", Jason.encode!(body))

      assert conn.status == 200
    end

    test "Valid Hubspot signature and old timestamp", %{conn: conn} do
      body = [%{"subscriptionType" => "fake", "objectTypeId" => "fake"}]
      timestamp = :os.system_time(:millisecond) - 6 * 1000
      request_uri = System.get_env("BASE_URL") <> "/webhooks/v1/hubspot"
      client_secret = System.get_env("HUBSPOT_CLIENT_SECRET")

      signature =
        :hmac
        |> :crypto.mac(:sha256, client_secret, "POST#{request_uri}#{Jason.encode!(body)}#{timestamp}")
        |> Base.encode64()

      conn =
        conn
        |> put_req_header("x-hubspot-signature-v3", signature)
        |> put_req_header("x-hubspot-request-timestamp", to_string(timestamp))
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/v1/hubspot", Jason.encode!(body))

      assert conn.status == 401
    end

    test "Invalid Hubspot signature and valid timestamp", %{conn: conn} do
      body = [%{"subscriptionType" => "fake", "objectTypeId" => "fake"}]
      timestamp = :os.system_time(:millisecond)
      request_uri = System.get_env("BASE_URL") <> "/webhooks/v1/hubspot"
      client_secret = "Fake client secret"

      signature =
        :hmac
        |> :crypto.mac(:sha256, client_secret, "POST#{request_uri}#{Jason.encode!(body)}#{timestamp}")
        |> Base.encode64()

      conn =
        conn
        |> put_req_header("x-hubspot-signature-v3", signature)
        |> put_req_header("x-hubspot-request-timestamp", to_string(timestamp))
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/v1/hubspot", Jason.encode!(body))

      assert conn.status == 401
    end
  end
end
