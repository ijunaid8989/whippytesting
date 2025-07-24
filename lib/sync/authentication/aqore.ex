defmodule Sync.Authentication.Aqore do
  @moduledoc """
  Handles Aqore authentication with Aqore API.
  """

  import Sync.Clients.Aqore.Common
  import Sync.Clients.Aqore.Parser

  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Utils.Http.Retry

  require Logger

  @token_validity_allowance 60
  @generate_access_token_grant_type "client_credentials"

  def get_integration_details(%Integration{id: integration_id} = integration) do
    # Get latest authentication settings - requests made get updated each time this function is called
    %Integration{
      authentication:
        %{"requests_made" => latest_requests_made, "access_token" => access_token, "base_api_url" => api_url} =
          authentication
    } = Integrations.get_integration!(integration_id)

    %{"exp" => expires_at, "client_requestLimit" => max_requests_limit_on_token} =
      jwt_decode(access_token)

    # Convert max_requests_limit_on_token to integer
    max_requests_limit = String.to_integer(max_requests_limit_on_token)

    # Increment requests made
    new_requests_made = latest_requests_made + 1

    if expired?(expires_at) or new_requests_made >= max_requests_limit do
      {:ok, updated_token} = generate_access_token(integration)

      # Update integration with new token, reset requests made
      authentication
      |> Map.put("access_token", updated_token)
      |> Map.put("requests_made", 1)
      |> then(&Integrations.update_integration(integration, %{authentication: &1}))

      {:ok, %{"base_api_url" => api_url, "access_token" => updated_token}}
    else
      # Update integration with new requests made
      authentication
      |> Map.put("requests_made", new_requests_made)
      |> then(&Integrations.update_integration(integration, %{authentication: &1}))

      {:ok, %{"base_api_url" => api_url, "access_token" => access_token}}
    end
  end

  def generate_access_token(%Integration{
        authentication: %{"client_id" => client_id, "client_secret" => client_secret, "base_api_url" => api_url}
      }) do
    url = "#{api_url}/connect/token"
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    body = [
      {"grant_type", @generate_access_token_grant_type},
      {"client_Id", client_id},
      {"client_Secret", client_secret}
    ]

    http_request_function = fn ->
      HTTPoison.post(url, {:form, body}, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response()
    |> case do
      {:ok, body} ->
        parse(body, :access_token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  #############
  ## Helpers ##
  #############

  # Extracts the payload from the JWT and decodes it
  def jwt_decode(token) do
    [_, payload, _] = String.split(token, ".")

    payload
    |> base64_decode()
    |> Jason.decode!()
  end

  # Decodes the base64 encoded JWT
  defp base64_decode(encoded) do
    encoded
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!(padding: false)
  end

  # Checks if the token is expired when expires_at is an integer representing a Unix timestamp
  def expired?(expires_at) when is_integer(expires_at) do
    DateTime.to_unix(DateTime.utc_now()) >= expires_at - @token_validity_allowance
  end

  # Checks if the token is expired when expires_at is a string
  # by parsing it into an integer Unix timestamp
  def expired?(expires_at) when is_binary(expires_at) do
    case Integer.parse(expires_at) do
      {expires_at_int, _} -> expired?(expires_at_int)
      # Consider invalid format as expired
      :error -> true
    end
  end

  # Fallback clause assuming the token is expired if expires_at is in an unexpected format
  def expired?(_expires_at), do: true
end
