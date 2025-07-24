defmodule Sync.Clients.Avionte.Resources.Branch do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  alias Sync.Utils.Http.Retry

  @doc """
  Lists the all the branches in Avionte.
  This endpoint does not accept query or path parameters with which to control the amount of data returned.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'

  ## Returns
    - `{:ok, [response_map()]}` - A list maps containing the external channel id and the external channel as Branch.t().
    - `{:error, term()}` - The error message.
  """
  @type response_map :: %{external_channel_id: binary(), external_channel: Branch.t()}
  @spec list_branches(String.t(), String.t(), String.t()) :: {:ok, [response_map()]} | {:error, term()}
  def list_branches(api_key, bearer_token, tenant) do
    url = "#{get_base_url()}/branch"
    headers = get_headers(api_key, bearer_token, tenant)

    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :branches))
  end
end
