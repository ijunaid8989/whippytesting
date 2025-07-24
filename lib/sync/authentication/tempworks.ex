defmodule Sync.Authentication.Tempworks do
  @moduledoc """
  Handles authentication with the TempWorks API.

  This module provides functions for obtaining two types of authentication tokens:

  1. Service Token ("Service Auth"):
     - Used for most requests to the TempWorks API.
     - Valid for 1 hour.
     - Requires one API call to obtain the token.
     - Can be used to authenticate an application to the TempWorks API.

  2. User Token ("Service Rep"):
     - Used for requests to the TempWorks API that write messages in their system.
     - Requires a redirect flow to obtain the token through a TempWorks user (Contact or Employee).
     - Obtained using the OAuth 2.0 Authorization Code Flow with PKCE (Proof Key for Code Exchange).

  The user authorization flow for obtaining the User Token is as follows:

  1. Generate an authorization URL with the required parameters, including the callback/redirect URL, code challenge (for PKCE), and other necessary parameters.
  2. Direct the user to the authorization URL, which opens a login form.
  3. After successful login, the user is redirected back to the specified redirect URL, which includes the authorization code.
  4. Exchange the authorization code and code verifier for a user token.

  PKCE verification is used to enhance security. It involves generating a code verifier (a random string) and a code challenge (a SHA256 hash of the code verifier). The code challenge is included in the authorization URL, while the code verifier is used when exchanging the authorization code for the user token.

  The code verifier is stored in the database associated with a newly created user when generating the authorization URL. The user ID is included as a state parameter in the URL. During the callback, the user ID is used to retrieve the user record and the stored code verifier, which is then used to exchange the authorization code for the user token.

  This module provides functions to handle the various steps of the authentication process, including generating the authorization URL, exchanging the authorization code for a token, and making authenticated requests to the TempWorks API using the obtained tokens.
  """

  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Integrations.User

  require Logger

  @type integration :: Integrations.Integration.t()
  @type user_id :: String.t()

  @base_url "https://login.ontempworks.com"
  @token_url "/connect/token"
  @authorization_url "/connect/authorize"
  @redirect_endpoint "/v1/tempworks/auth/redirect"
  @default_scopes "assignment-write contact-write customer-write document-write employee-write hotlist-write message-write offline_access openid ordercandidate-write order-write profile universal-search"
  @default_headers %{"Content-Type" => "application/x-www-form-urlencoded"}
  @length 32
  @token_validity_allowance 240

  @doc """
  [Service Auth] Retrieves or regenerates the service token for the given integration.

  Returns the access token on success, or an error tuple if the integration is invalid.
  """
  @spec get_or_regenerate_service_token(integration()) :: {:ok, Integration.t()} | {:error, String.t()}
  def get_or_regenerate_service_token(
        %Integration{
          authentication: %{
            "client_id" => client_id,
            "client_secret" => client_secret,
            "acr_values" => acr_values,
            "token_expires_at" => token_expires_at
          }
        } = integration
      )
      when is_binary(client_id) and is_binary(client_secret) and is_binary(acr_values) do
    if expired?(token_expires_at) do
      Logger.info("Token is expired, refreshing...")
      refresh_service_token(integration)
    else
      {:ok, integration}
    end
  end

  def get_or_regenerate_service_token(
        %Integration{
          authentication: %{"client_id" => client_id, "client_secret" => client_secret, "acr_values" => acr_values}
        } = integration
      )
      when is_binary(client_id) and is_binary(client_secret) and is_binary(acr_values) do
    refresh_service_token(integration)
  end

  def get_or_regenerate_service_token(_invalid_integration),
    do: {:error, "Invalid integration. Integration is not set up for service token retrieval."}

  @doc """
  [Service Rep] Retrieves user authentication and refreshes the token if it is expired.
  """
  @spec get_or_regenerate_user_token(Integrations.User.t()) :: map() | {:error, String.t()}
  def get_or_regenerate_user_token(%Integrations.User{authentication: user_authentication} = user) do
    id_token = user_authentication["id_token"]
    parsed_payload = Integrations.extract_jwt_payload(id_token)

    # Check if the token is expired
    unix_time_now = DateTime.to_unix(DateTime.utc_now())

    if parsed_payload["exp"] <= unix_time_now - @token_validity_allowance do
      {:ok, refreshed_user} = refresh_user_token(user)

      {:ok, refreshed_user}
    else
      {:ok, user}
    end
  end

  def get_or_regenerate_user_token(_user), do: {:error, "Invalid user"}

  @doc """
  [Service Rep] Generates a user-specific authorization URL for TempWorks OAuth flow.

  Accepts an integration struct and returns a URL for user authorization.
  Setting overwrites can be provided in the integration settings in the integration struct.

  A challenge is generated for the PKCE flow and a user is created in the database with the challenge.
  The user ID is attached to the URL as a state parameter, which is used in the callback to identify the user.
  """

  @spec get_user_authorization_url(Integration.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def get_user_authorization_url(
        %Integration{authentication: authentication, settings: settings} = integration,
        whippy_user_id
      )
      when is_map(authentication) and is_map(settings) and is_binary(whippy_user_id) do
    case Integrations.get_user_by_whippy_id(integration.id, whippy_user_id) do
      %User{} ->
        # Generate PKCE challenge and verifier for secure OAuth flow
        challenge = generate_challenge()

        # Create a user entry to store PKCE information and associate with integration
        {:ok, user} =
          Integrations.create_or_update_user(
            integration.id,
            whippy_user_id,
            %{
              authentication: %{
                code_verifier: challenge.code_verifier,
                code_challenge: challenge.code_challenge
              },
              integration_id: integration.id,
              external_organization_id: integration.external_organization_id,
              whippy_user_id: whippy_user_id
            }
          )

        # Prepare parameters for the authorization URL
        params = %{
          client_id: authentication["client_id"],
          response_type: "code",
          scope: authentication["scope"] || @default_scopes,
          redirect_uri: get_host() <> @redirect_endpoint,
          code_challenge_method: "S256",
          code_challenge: challenge.code_challenge,
          # User ID to associate with the authorization URL, used in the callback to identify the user
          state: user.id
        }

        # Determine the base URL and construct the full authorization URL
        base_url = settings["base_url"] || @base_url
        authorization_url = base_url <> @authorization_url <> "?" <> URI.encode_query(params)

        {:ok, authorization_url}

      _no_user ->
        {:error, "User not found"}
    end
  end

  def get_user_authorization_url(integration, whippy_user_id) when is_integer(whippy_user_id) do
    binary_whippy_user_id = Integer.to_string(whippy_user_id)

    get_user_authorization_url(integration, binary_whippy_user_id)
  end

  def get_user_authorization_url(_invalid_integration, _whippy_user_id), do: {:error, "Invalid integration"}

  @doc """
  [Service Rep] Refreshes the user's authentication tokens using the refresh token.

  Accepts a user struct and returns a map with the refreshed tokens.
  """
  @spec refresh_user_token(Integrations.User.t()) :: {:ok, Integrations.User.t()} | {:error, String.t()}
  def refresh_user_token(%Integrations.User{authentication: %{"refresh_token" => refresh_user_token}} = user)
      when is_binary(refresh_user_token) do
    # Retrieve integration details for the user
    %Integration{authentication: integration_authentication} =
      integration = Integrations.get_integration!(user.integration_id)

    # Prepare headers for the HTTP request
    headers = authentication_headers(integration)

    # Set parameters for the token refresh request
    params = %{
      grant_type: "refresh_token",
      client_id: integration_authentication["client_id"],
      client_secret: integration_authentication["client_secret"],
      refresh_token: refresh_user_token,
      acr_values: integration_authentication["acr_values"]
      # redirect_uri: get_host() <> @redirect_endpoint
    }

    # Construct the full URL for the token refresh request
    full_url = @base_url <> @token_url
    response = HTTPoison.post(full_url, URI.encode_query(params), headers)

    # Handle the HTTP response
    case parse_oauth_token_response(response) do
      {:ok, token_data} ->
        Integrations.handle_user_token_data(user, token_data, integration)

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def refresh_user_token(%Integrations.User{authentication: %{"refresh_token" => nil}}) do
    {:error, "Invalid or missing refresh token"}
  end

  def refresh_user_token(_user), do: {:error, "Invalid user"}

  @doc """
  [Service Rep] Exchanges the authorization code for a user token.

  This is the last step in the OAuth flow for TempWorks.
  The code_verifier was stored during the get_user_authorization_url step.
  A request is made to the TempWorks API to exchange the code for a user token.
  The user token is then stored in the user's authentication data.
  """
  @spec exchange_code_for_token(user_id(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def exchange_code_for_token(user_id, code) when is_binary(code) do
    user = Integrations.get_user!(user_id)
    authentication = user.authentication
    Logger.info("Exchanging code: #{code} with verifier: #{authentication["code_verifier"]}")

    integration = Integrations.get_integration!(user.integration_id)
    settings = integration.settings

    headers = authentication_headers(integration)

    params = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: get_host() <> @redirect_endpoint,
      code_verifier: authentication["code_verifier"]
    }

    base_url = settings["base_url"] || @base_url
    response = HTTPoison.post(base_url <> @token_url, URI.encode_query(params), headers)

    case parse_oauth_token_response(response) do
      {:ok, token_data} ->
        Integrations.update_user(user, %{"completed_at" => DateTime.utc_now()})
        Integrations.handle_user_token_data(user, token_data, integration)

      {:error, reason} ->
        Logger.error("Failed to exchange code for token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def exchange_code_for_token(_user_id, _code), do: {:error, "Invalid payload data"}

  @doc """
  [Service Auth] Refreshes the service token for the given integration.

  Fetches a new token from the TempWorks API and updates the integration's authentication data.
  Returns the new access token on success, or an error tuple on failure.
  """
  @spec refresh_service_token(Integration.t()) :: {:ok, Integration.t()} | {:error, String.t()}
  def refresh_service_token(
        %Integration{
          authentication: %{"client_id" => client_id, "client_secret" => client_secret, "acr_values" => acr_values}
        } = integration
      )
      when is_binary(client_id) and is_binary(client_secret) and is_binary(acr_values) do
    params = [
      grant_type: "tw_vendor_service_credentials",
      client_id: client_id,
      client_secret: client_secret,
      acr_values: acr_values
    ]

    output = HTTPoison.post(@base_url <> @token_url, URI.encode_query(params), @default_headers)

    case parse_oauth_token_response(output) do
      {:ok, %{"access_token" => _access_token} = token_data} ->
        Integrations.handle_service_token_data(integration, token_data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_service_token(_invalid_integration_missing_parameters),
    do: {:error, "Error refreshing service token. Invalid integration configuration."}

  def default_scopes, do: @default_scopes

  ####################
  # Helper functions #
  ####################

  # Checks if the token is expired when expires_at is an integer representing a Unix timestamp
  defp expired?(expires_at) when is_integer(expires_at) do
    DateTime.to_unix(DateTime.utc_now()) >= expires_at - @token_validity_allowance
  end

  # Checks if the token is expired when expires_at is a string
  # by parsing it into an integer Unix timestamp
  defp expired?(expires_at) when is_binary(expires_at) do
    {expires_at_int, _} = Integer.parse(expires_at)
    expired?(expires_at_int)
  end

  # Fallback clause assuming the token is expired if expires_at is in an unexpected format
  defp expired?(_expires_at), do: true

  defp get_host do
    System.get_env("BASE_URL", "http://localhost:4000")
  end

  defp authentication_headers(%Integration{authentication: authentication}) do
    [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization",
       "Basic " <>
         Base.encode64("#{authentication["client_id"]}:#{authentication["client_secret"]}")}
    ]
  end

  defp authentication_headers(_), do: {:error, "Invalid Integration"}

  defp random_string(length \\ @length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp generate_challenge do
    state = random_string()
    code_verifier = random_string()
    code_challenge = :sha256 |> :crypto.hash(code_verifier) |> Base.url_encode64(padding: false)

    %{
      state: state,
      code_verifier: code_verifier,
      code_challenge: code_challenge
    }
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
end
