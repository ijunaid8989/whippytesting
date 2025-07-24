defmodule Sync.Clients.Tempworks.Resources.Assignment do
  @moduledoc false

  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Model.CustomData
  alias Sync.Clients.Tempworks.Model.EmployeeAssignment
  alias Sync.Clients.Tempworks.Parser
  alias Sync.Utils.Http.Retry

  @request_opts [recv_timeout: 60_000]

  # https://developer.ontempworks.com/docs/advanced-searching#OriginTypes
  @assignment_origin_type_id 14

  @doc """
  List the assignments tied to the organization. If no limit or offset is provided, we will default
  to an offset of 0 and a limit of 100. If no is_active is provided, we will default to nil, which will
  return all assignments regardless of their activity status.

  TempWorks have 2 endpoints that return a list of assignments:
    - /Search/Assignments - https://api.ontempworks.com/swagger/index.html#/Searches/SearchAssignmentsGet
    - /Employees/{id}/assignments - https://api.ontempworks.com/swagger/index.html#/Employees/EmployeesByIdAssignmentsGet

  The responses from both endpoints are identical, so the same parser can be used for both.

  The first one is not limited to a specific employee and returns a list of assignments for all employees. This is the
  implementation of this function.

  The second one is limited to a specific employee and returns a list of assignments for that employee, its implementation
  is defined in the Employee module.
  """
  @type list_opt :: {:limit, non_neg_integer()} | {:offset, non_neg_integer()} | {:is_active, boolean()}
  @type response_map :: {:ok, %{assignments: [EmployeeAssignment.t()], total: non_neg_integer()}}
  @spec list_assignments(binary(), [list_opt()]) :: {:ok, response_map()} | {:error, term()}
  def list_assignments(access_token, opts \\ []) do
    url = "#{get_base_url()}/Search/Assignments"
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
    |> Retry.request(max_attempts: 5, delay: 1500)
    |> handle_response(&Parser.parse_employee_assignments/1)
  end

  @doc """
  Fetches the custom data for a specific assignment.
  """
  @type custom_data_response_map :: {:ok, %{custom_data: [CustomData.t()], total: non_neg_integer()}}
  @spec get_assignment_custom_data(binary(), non_neg_integer()) ::
          {:ok, custom_data_response_map()} | {:error, term()}
  def get_assignment_custom_data(access_token, assignment_id) do
    url = "#{get_base_url()}/Assignments/#{assignment_id}/CustomData"

    http_request_function = fn ->
      HTTPoison.get(url, get_headers(access_token, :get), recv_timeout: 30_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1500)
    |> handle_response(&Parser.parse_custom_data_set/1)
  end

  ##################
  # Advance Search #
  ##################

  @spec list_assignment_columns(binary()) :: {:ok, map()} | {:error, term()}
  def list_assignment_columns(access_token) do
    url = "#{get_base_url()}/search/#{@assignment_origin_type_id}/columns"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn response -> {:ok, response} end)
  end

  @spec list_assignments_advance_details(binary(), list()) :: {:ok, map()} | {:error, term()}
  def list_assignments_advance_details(access_token, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    returned_columns = Keyword.get(opts, :columns, [])

    url = "#{get_base_url()}/search/#{@assignment_origin_type_id}"
    headers = get_headers(access_token, :post)
    columns = prepare_assignment_query(returned_columns, limit, offset)

    url
    |> HTTPoison.post(columns, headers, @request_opts)
    |> handle_response(&Parser.parse_advance_assignment_search/1)
  end

  defp prepare_assignment_query(returned_columns, limit, offset) do
    Jason.encode!(
      %{
        "searchCriteria" => %{
          "rootGroup" => %{
            "condition" => 0,
            "not" => false,
            # Assignment Status is open
            "rules" => [%{"columnId" => "bfac4935-a18f-48b1-9670-9a627415d407", "operatorId" => 7, "values" => ["26"]}]
          },
          "returnColumnIds" => returned_columns
        },
        "sortByColumns" => [
          # last_name
          %{"columnId" => "7674fd28-8ae1-4608-a1f5-40aa4dfb0be5", "isDescending" => false},
          # Assignment Id
          %{"columnId" => "c9d2d4e9-aced-4b54-8328-efcd7c4a95f5", "isDescending" => false}
        ],
        "ignoreCachedResults" => true,
        "skip" => offset,
        "take" => limit
      },
      escape: :unicode_safe
    )
  end
end
