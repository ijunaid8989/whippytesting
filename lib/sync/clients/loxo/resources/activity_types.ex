defmodule Sync.Clients.Loxo.Resources.ActivityTypes do
  @moduledoc """
  This module contains functions that interact with the Loxo API to get and create activity data.
  """

  import Sync.Clients.Loxo.Common
  import Sync.Clients.Loxo.Parser

  require Logger

  @doc """
  Makes a request to the Loxo API to get a list of activity types for a given agency.

  ## Arguments
   - `api_key` - The API key to authenticate with the Loxo API
   - `agency_slug` - The slug of the agency to get the activity types from

  ## Returns
    - `{:ok, list(sync_activity_type)}` - The list of activity types
    - `{:error, term()}` - The error message
  """
  @type sync_activity_type :: %{activity_type_id: integer(), name: String.t()}
  @spec list_activity_types(binary(), binary()) ::
          {:ok, list(sync_activity_type)} | {:error, term()}
  def list_activity_types(api_key, agency_slug) do
    url = "#{get_base_url()}/#{agency_slug}/activity_types"
    headers = get_headers(api_key)

    url
    |> HTTPoison.get(headers)
    |> handle_response(&parse(&1, :activity_types))
  end
end
