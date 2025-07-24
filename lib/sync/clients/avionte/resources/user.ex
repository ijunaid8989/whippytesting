defmodule Sync.Clients.Avionte.Resources.User do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  alias Sync.Utils.Http.Retry

  @doc """
  Lists the IDs of users in Avionte.

  It returns a list of integers representing the IDs of users.
  `page` and `page_size` are optional parameters and default to 1 and 50, respectively.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'
    - `opts` - The options for listing user IDs.
      - `limit` - The number of users to return.
      - `offset` - The number of users to skip.


  ## Returns
    - `{:ok, [non_neg_integer()]}` - The list of user IDs.
    - `{:error, term()}` - The error message.
  """
  @type list_user_ids_opts :: [limit: non_neg_integer(), offset: non_neg_integer()]
  @spec list_user_ids(String.t(), String.t(), String.t(), list_user_ids_opts()) ::
          {:ok, [non_neg_integer()]} | {:error, term()}
  def list_user_ids(api_key, bearer_token, tenant, opts \\ []) do
    opts = Keyword.validate!(opts, limit: 50, offset: 0)
    {page, page_size} = page_and_page_size(opts)

    url = "#{get_base_url()}/users/ids/#{page}/#{page_size}/"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :user_ids))
  end

  @doc """
  Lists the users in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'


  ## Returns
    - `{:ok, [User.t()]}` - The list of users.
    - `{:error, term()}` - The error message.
  """
  @type opts :: [user_ids: [non_neg_integer()]]
  @type user_map :: %{
          external_user_id: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          email: String.t()
        }
  @spec list_users(String.t(), String.t(), String.t()) :: {:ok, [user_map()]} | {:error, term()}
  def list_users(api_key, bearer_token, tenant) do
    url = "#{get_base_url()}/users"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :users))
  end
end
