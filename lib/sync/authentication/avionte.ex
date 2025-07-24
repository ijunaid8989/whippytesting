defmodule Sync.Authentication.Avionte do
  @moduledoc """
  Handles authentication with Avionte API.

  Avionte's authentication is done through a POST request to the authorize/token endpoint.
  The endpoint returns an access token that is used in subsequent requests with validity of 1 hour.

  The access token and its expiration time are stored in the authentication field of the respective Integration record.
  """

  alias Sync.Integrations
  alias Sync.Integrations.Integration

  require Logger

  @token_endpoint "/authorize/token"
  @default_grant_type "client_credentials"
  @default_scope "avionte.aero.compasintegrationservice"
  @invalid_authentication_message "Missing authentication credentials. client_id, client_secret, and external_api_key are required."

  @doc """
  Get the Avionte API key from the authentication field of the Integration record.

  ## Arguments
  * `integration` - Integration record containing the authentication field with the api_key

  ## Returns
  * `{:ok, binary()}` - API key if present in the authentication field
  * `{:error, String.t()}` - If the API key could not be retrieved
  """
  @spec get_api_key(Integration.t()) :: {:ok, binary()} | {:error, String.t()}
  def get_api_key(%Integration{authentication: %{"external_api_key" => api_key}}) when is_binary(api_key) do
    {:ok, api_key}
  end

  def get_api_key(_integration), do: {:error, "Invalid or missing Avionte API key"}

  @doc """
  Get the Avionte tenant from the authentication field of the Integration record.

  ## Arguments
  * `integration` - Integration record containing the authentication field with the tenant

  ## Returns
  * `{:ok, binary()}` - Tenant if present in the authentication field
  * `{:error, String.t()}` - If the tenant could not be retrieved
  """
  @spec get_tenant(Integration.t()) :: {:ok, binary()} | {:error, String.t()}
  def get_tenant(%Integration{authentication: %{"tenant" => tenant}}) when is_binary(tenant) do
    {:ok, tenant}
  end

  def get_tenant(_integration), do: {:error, "Invalid or missing Avionte tenant"}

  @doc """
  Get the access token from the authentication field of the Integration record.
  If the access token is expired, regenerate it and update the authentication field of the Integration record.

  ## Arguments
  * `integration` - Integration record containing the authentication field with the client_id, client_secret, scope, and api_key

  ## Returns
  * `{:ok, binary(), Integration.t()}` - Access token, Integration record with updated authentication field
  * `{:error, term()}` - If the access token could not be retrieved or regenerated
  """
  @spec get_or_regenerate_access_token(Integration.t()) :: {:ok, binary(), Integration.t()} | {:error, term()}
  def get_or_regenerate_access_token(%Integration{} = integration) do
    case maybe_update_token(integration) do
      {:ok, %Integration{authentication: %{"access_token" => token}} = integration} ->
        {:ok, token, integration}

      error ->
        Logger.error("Error getting or regenerating Avionte access token: #{inspect(error)}")
        {:error, error}
    end
  end

  # Check if the access token is expired and update it if it is
  defp maybe_update_token(%Integration{authentication: authentication} = integration) do
    if expired?(authentication["token_expires_in"]), do: update_token(integration), else: {:ok, integration}
  end

  # Update the access token in the authentication field of the Integration record
  # with the new access token and its expiration time
  def update_token(%Integration{authentication: authentication} = integration) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- get_access_token(authentication),
         {:ok, %{"access_token" => access_token, "expires_in" => expires_in}} <- Jason.decode(body) do
      updated_expires_in = DateTime.to_unix(DateTime.utc_now()) + expires_in

      authentication
      |> Map.put("access_token", access_token)
      |> Map.put("token_expires_in", updated_expires_in)
      |> then(&Integrations.update_integration(integration, %{authentication: &1}))
    else
      error ->
        error
        |> inspect()
        |> Logger.error()

        error
    end
  end

  # Get access token from Avionte's API
  defp get_access_token(
         %{"client_id" => client_id, "client_secret" => client_secret, "external_api_key" => api_key} = authentication
       )
       when is_binary(client_id) and is_binary(client_secret) and is_binary(api_key) do
    params = [
      client_id: client_id,
      client_secret: client_secret,
      grant_type: authentication["grant_type"] || @default_grant_type,
      scope: authentication["scope"] || @default_scope
    ]

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Accept", "application/json"},
      {"X-Api-Key", api_key}
    ]

    HTTPoison.post(base_url() <> @token_endpoint, URI.encode_query(params), headers)
  end

  defp get_access_token(_authentication), do: {:error, @invalid_authentication_message}

  defp expired?(expires_in) when is_integer(expires_in), do: DateTime.to_unix(DateTime.utc_now()) >= expires_in
  defp expired?(_expires_in), do: true

  defp base_url, do: Application.get_env(:sync, :avionte_api)
end
