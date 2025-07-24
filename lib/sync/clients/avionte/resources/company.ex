defmodule Sync.Clients.Avionte.Resources.Company do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  alias Sync.Utils.Http.Retry

  @doc """
  Get the ID of a company.
  """
  @type get_ids_opts :: [limit: non_neg_integer(), offset: non_neg_integer()]
  @spec list_company_ids(String.t(), String.t(), String.t(), get_ids_opts()) :: {:ok, [map()]} | {:error, term()}
  def list_company_ids(api_key, bearer_token, tenant, opts) do
    {page, page_size} = page_and_page_size(opts)
    url = "#{get_base_url()}/companies/ids/#{page}/#{page_size}/"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :company_ids))
  end

  @type opts :: [ids: [non_neg_integer()]]
  @spec list_companies(String.t(), String.t(), String.t(), opts()) :: {:ok, [map()]} | {:error, term()}
  def list_companies(api_key, bearer_token, tenant, opts) do
    ids = Keyword.get(opts, :ids)
    url = "#{get_base_url()}/companies/multi-query"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.post(url, Jason.encode!(ids), headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :companies))
  end
end
