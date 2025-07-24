defmodule Sync.Clients.Loxo.Resources.Users do
  @moduledoc false

  import Sync.Clients.Loxo.Common
  import Sync.Clients.Loxo.Parser

  require Logger

  @doc """
  List users from Loxo

  As of 22nd July 2024, there is no pagination options with Loxo. It appears to return all users in one go.
  Notes here: https://linear.app/whippy/issue/WHI-3938/loxo-integration-overview#comment-12d4cccb

  ## Arguments
  - `api_key` - Loxo API Key
  - `agency_slug` - Loxo agency slug for the organisation
  """
  def list_users(api_key, agency_slug) do
    url = "#{get_base_url()}/#{agency_slug}/users"
    headers = [{"Authorization", "Bearer #{api_key}"}]

    response = url |> HTTPoison.get(headers) |> handle_response()

    case response do
      {:ok, loxo_users} ->
        parse(loxo_users, :users)

      {:error, error} ->
        {:error, error}
    end
  end
end
