defmodule Sync.Authentication.Crelate do
  @moduledoc """
  Handles authentication with Crelate API.

  Crelate's authentication is done through a POST request to the authorize/token endpoint.
  The endpoint returns an access token that is used in subsequent requests with validity of 1 hour.

  The access token and its expiration time are stored in the authentication field of the respective Integration record.
  """
  alias Sync.Integrations.Integration

  @doc """
  Get the Crelate API key from the authentication field of the Integration record.

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

  def get_api_key(_integration), do: {:error, "Invalid or missing Crelate API key"}
end
