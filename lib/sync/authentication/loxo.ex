defmodule Sync.Authentication.Loxo do
  @moduledoc """
  Handles authentication with Loxo API.
  """

  alias Sync.Integrations.Integration

  require Logger

  @doc """
  Get the Loxo API key from the authentication field of the Integration record.

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

  def get_api_key(_integration), do: {:error, "Invalid or missing Loxo API key"}

  @doc """
  Get the Loxo agency slug from the authentication field of the Integration record.

  ## Arguments
  * `integration` - Integration record containing the authentication field with the tenant

  ## Returns
  * `{:ok, binary()}` - Tenant if present in the authentication field
  * `{:error, String.t()}` - If the tenant could not be retrieved
  """
  @spec get_agency_slug(Integration.t()) :: {:ok, binary()} | {:error, String.t()}
  def get_agency_slug(%Integration{authentication: %{"agency_slug" => agency_slug}}) when is_binary(agency_slug) do
    {:ok, agency_slug}
  end

  def get_agency_slug(_invalid_integration), do: {:error, "Invalid or missing Loxo agency slug"}
end
