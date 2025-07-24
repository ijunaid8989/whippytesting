defmodule Sync.Clients.Avionte.Common do
  @moduledoc """
  A list of common functions that the api shares.
  """

  require Logger

  @front_office_endpoint "/front-office/v1"

  @doc """
  Handles the response from the Avionte API.
  If the response is successful (status code is 200 or 201), the response body will be decoded and passed
  to the success_callback function.
  If the response is an error, it will return the error.

  ## Arguments
    - `response` - The HTTPoison response tuple that is returned after a request to the Avionte API.
    - `success_callback` - The function to call if the response is successful.

  ## Returns
    - `{:ok, term()}` - The result of the success_callback function.
    - `{:error, term()}` - The error tuple.
  """
  @type httpoison_response :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  @type success_callback :: (map() -> {:ok, any()})
  @spec handle_response(httpoison_response, success_callback) :: {:ok, term()} | {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}}, success_callback) when code in 200..201,
    do: body |> Jason.decode!() |> success_callback.()

  def handle_response({:error, %HTTPoison.Error{reason: reason}}, _success_callback), do: {:error, reason}

  def handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}} = error, _success_callback) do
    Logger.error("[Avionte] HTTP error, status code: #{code}, body: #{inspect(body)}")

    {:error, error}
  end

  @doc """
  Gets the headers for the Avionte API.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'

  ## Returns
    - `list()` - The list of headers.
  """
  @spec get_headers(binary(), binary(), binary()) :: list()
  def get_headers(api_key, bearer_token, tenant) do
    [
      {"X-API-KEY", api_key},
      {"Authorization", "Bearer " <> bearer_token},
      {"Tenant", tenant},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc """
  Gets the base URL for the Avionte API front office endpoint.
  """
  @spec get_base_url() :: binary()
  def get_base_url, do: Application.get_env(:sync, :avionte_api) <> @front_office_endpoint

  @doc """
  Converts the limit and offset found in a keywords list to a page and page size.
  In case limit and offset are not found in the keywords list, they will be added with default values of 50 and 0, respectively.
  """
  @spec page_and_page_size(list()) :: {non_neg_integer(), non_neg_integer()}
  def page_and_page_size(opts) do
    opts = Keyword.validate!(opts, limit: 50, offset: 0)

    page = div(opts[:offset], opts[:limit]) + 1
    page_size = opts[:limit]

    {page, page_size}
  end
end
