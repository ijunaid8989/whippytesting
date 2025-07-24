defmodule Sync.Clients.Tempworks.Resources.Jobs do
  @moduledoc false

  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Model.CustomData
  alias Sync.Clients.Tempworks.Parser
  alias Sync.Utils.Http.Retry

  @spec list_job_orders(binary()) :: {:ok, map()} | {:error, term()}
  def list_job_orders(access_token, opts \\ []) do
    url = "#{get_base_url()}/Search/JobOrders"
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    is_active = Keyword.get(opts, :is_active, nil)
    branch_id = Keyword.get(opts, :branch_id, nil)

    params =
      if branch_id do
        [take: limit, skip: offset, isActive: is_active, branchId: branch_id]
      else
        [take: limit, skip: offset, isActive: is_active]
      end

    # Note: Tempworks uses the terms take for limit and skip for offset
    http_request_function = fn ->
      HTTPoison.get(url, get_headers(access_token, :get), params: params, recv_timeout: 45_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_job_orders/1)
  end

  @doc """
  Fetches the custom data for a specific Job Order ID.
  """
  @type custom_data_response_map :: {:ok, %{custom_data: [CustomData.t()], total: non_neg_integer()}}
  @spec get_job_orders_custom_data(binary(), non_neg_integer()) ::
          {:ok, custom_data_response_map()} | {:error, term()}
  def get_job_orders_custom_data(access_token, order_id) do
    url = "#{get_base_url()}/JobOrders/#{order_id}/CustomData"

    http_request_function = fn ->
      HTTPoison.get(url, get_headers(access_token, :get), recv_timeout: 30_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_custom_data_set/1)
  end
end
