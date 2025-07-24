defmodule Sync.Authentication.Hubspot do
  @moduledoc """
  Handles authentication with the Hubspot API.

  This module provides functions for obtaining authentication token:

    - Used for requests to the Hubspot API that write messages in their system.
    - Requires a redirect flow to obtain the token through a Hubspot user (Contact or Employee).

  The user authorization flow for obtaining the User Token is as follows:

  1. Generate an authorization URL with the required parameters, including the callback/redirect URL and other necessary parameters.
  2. Direct the user to the authorization URL, which opens a login form.
  3. After successful login, the user is redirected back to the specified redirect URL, which includes the authorization code.
  4. Exchange the authorization code and code verifier for a user token.


  This module provides functions to handle the various steps of the authentication process, including generating the authorization URL, exchanging the authorization code for a token, and making authenticated requests to the Hubspot API using the obtained tokens.
  """

  alias DashboardApi.Workers.Integrations
  alias Sync.Clients.Whippy
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  require Logger

  @type integration :: Integrations.Integration.t()
  @type organization_id :: String.t()

  @auth_base_url "https://app-eu1.hubspot.com"
  @auth_path "/oauth/authorize"
  @token_path "/oauth/v1/token"
  @account_info_path "/account-info/v3/details"

  @scopes "conversations.read conversations.write crm.objects.contacts.read crm.objects.contacts.write oauth timeline crm.objects.owners.read"
  @optional_scopes "automation"

  @redirect_path "/v1/hubspot/auth/redirect"

  @client_id System.get_env("HUBSPOT_CLIENT_ID")
  @client_secret System.get_env("HUBSPOT_CLIENT_SECRET")

  @spec get_user_authorization_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def get_user_authorization_url(organization_id, api_key) when is_binary(organization_id) do
    # Prepare parameters for the authorization URL
    state =
      %{"organization_id" => organization_id, "api_key" => api_key}
      |> Jason.encode!()
      |> Base.encode64()

    params = %{
      client_id: @client_id,
      scope: @scopes,
      optional_scope: @optional_scopes,
      redirect_uri: get_host() <> @redirect_path,
      state: state
    }

    # Determine the base URL and construct the full authorization URL
    authorization_url = @auth_base_url <> @auth_path <> "?" <> URI.encode_query(params)

    {:ok, authorization_url}
  end

  def get_user_authorization_url(_whippy_organisation_id, _whippy_api_key), do: {:error, "Invalid integration"}

  @spec exchange_code_for_token(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def exchange_code_for_token(organization_id, api_key, code) when is_binary(code) do
    headers = %{:"Content-Type" => "application/x-www-form-urlencoded;charset=utf-8"}

    params = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: get_host() <> @redirect_path,
      client_id: @client_id,
      client_secret: @client_secret
    }

    response =
      HTTPoison.post(
        Application.get_env(:sync, :hubspot_api) <> @token_path,
        URI.encode_query(params),
        headers
      )

    case parse_oauth_token_response(response) do
      {:ok, token_data} ->
        case Integrations.get_integration(organization_id, :hubspot) do
          %Integration{} = integration ->
            Integrations.update_integration(integration, %{
              "authentication" => Map.put(token_data, "whippy_api_key", api_key)
            })

            update_integration_portal_id(integration)

            %{"integration_id" => integration.id, "type" => "initial_sync"}
            |> Sync.Workers.Hubspot.new()
            |> Oban.insert()

          nil ->
            {:ok, integration} =
              Integrations.create_integration(%{
                "integration" => "Hubspot",
                "external_organization_id" => "N/A",
                "whippy_organization_id" => organization_id,
                "client" => :hubspot,
                "authentication" => Map.put(token_data, "whippy_api_key", api_key),
                "settings" => %{daily_sync_at: "30 12 * * *"}
              })

            %{"integration_id" => integration.id, "type" => "initial_sync"}
            |> Sync.Workers.Hubspot.new()
            |> Oban.insert()

            update_integration_portal_id(integration)
            Whippy.create_integration(integration.authentication["whippy_api_key"], integration)
        end

        {:ok, token_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def exchange_code_for_token(_, _), do: {:error, "Invalid payload data"}

  @spec refresh_token!(Integration.t()) :: Integration.t()
  def refresh_token!(integration) do
    headers = %{:"Content-Type" => "application/x-www-form-urlencoded;charset=utf-8"}

    params = %{
      grant_type: "refresh_token",
      refresh_token: integration.authentication["refresh_token"],
      redirect_uri: get_host() <> @redirect_path,
      client_id: @client_id,
      client_secret: @client_secret
    }

    response =
      HTTPoison.post(
        Application.get_env(:sync, :hubspot_api) <> @token_path,
        URI.encode_query(params),
        headers
      )

    case parse_oauth_token_response(response) do
      {:ok, token_data} ->
        authentication = Map.merge(integration.authentication, token_data)

        {:ok, integration} =
          Integrations.update_integration(integration, %{
            "authentication" => authentication
          })

        integration

      {:error, reason} ->
        Logger.error("[Hubspot] Failed to refresh token. #{inspect(reason)}")
        raise reason
    end
  end

  ##################
  # Helper functions
  ##################

  defp update_integration_portal_id(integration) do
    response = Sync.Clients.Hubspot.get_client(integration).(:get, @account_info_path, %{}, false)

    Integrations.update_integration(integration, %{
      "external_organization_id" => to_string(response["portalId"])
    })
  end

  defp parse_oauth_token_response({:ok, %HTTPoison.Response{status_code: status, body: body}}) when status in 200..299 do
    case Jason.decode(body) do
      {:ok, token_data} ->
        {:ok, token_data}

      {:error, error} ->
        Logger.error("Failed to decode token response: #{inspect(error)}")
        {:error, "Failed to decode token response"}
    end
  end

  defp parse_oauth_token_response({:ok, %HTTPoison.Response{status_code: status, body: body}}) do
    Logger.error("Body Error: #{body}")
    {:error, "Token exchange failed with status #{status}: #{body}"}
  end

  defp parse_oauth_token_response({:error, %HTTPoison.Error{reason: reason}}) do
    Logger.error("HTTP Error: #{inspect(reason)}")
    {:error, reason}
  end

  defp get_host do
    System.get_env("BASE_URL", "http://localhost:#{System.get_env("PORT", "4001")}")
  end
end
