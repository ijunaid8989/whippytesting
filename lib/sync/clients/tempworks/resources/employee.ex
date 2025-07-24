defmodule Sync.Clients.Tempworks.Resources.Employee do
  @moduledoc false

  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Model.CustomData
  alias Sync.Clients.Tempworks.Model.EmployeeAssignment
  alias Sync.Clients.Tempworks.Model.EmployeeDetail
  alias Sync.Clients.Tempworks.Model.TempworkContactDetail
  alias Sync.Clients.Tempworks.Parser
  alias Sync.Utils.Http.Retry

  require Logger

  @request_opts [recv_timeout: 120_000]
  @advance_request_opts [recv_timeout: 360_000]

  # https://developer.ontempworks.com/docs/advanced-searching#OriginTypes
  @employee_origin_type_id 1

  @doc """
  ## Description

  List the employees tied to an organization. Note that if a limit or offset is not
  provided, the defaults will be used.
  ## Arguments

  - opts: A Keyword List of limit and/or offset
  """
  @type list_opt :: {:limit, non_neg_integer()} | {:offset, non_neg_integer()}
  @type employees_response_map :: %{
          employees: [
            %{
              external_contact_id: binary(),
              phone: binary(),
              name: binary(),
              email: binary(),
              external_contact: Employee.t(),
              external_organization_entity_type: binary()
            }
          ],
          total: non_neg_integer()
        }
  @spec list_employees(binary(), [list_opt()]) :: {:ok, employees_response_map} | {:error, term()}
  def list_employees(access_token, opts \\ []) do
    url = "#{get_base_url()}/Search/Employees"
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    is_active = Keyword.get(opts, :is_active, true)
    branch_id = Keyword.get(opts, :branch_id, nil)

    headers = get_headers(access_token, :get)

    params =
      if branch_id do
        [take: limit, skip: offset, isActive: is_active, branchId: branch_id]
      else
        [take: limit, skip: offset, isActive: is_active]
      end

    http_request_function = fn ->
      HTTPoison.get(url, headers, params: params, recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_employees/1)
  end

  @doc """
  On a successful request we will create the employee and return an {:ok, new_employee_id} response
  """
  @type create_params :: %{
          firstName: String.t(),
          lastName: String.t(),
          governmentPersonalId: String.t() | nil,
          bypassAddressValidationService: boolean(),
          street1: String.t() | nil,
          street2: String.t() | nil,
          municipality: String.t() | nil,
          region: String.t(),
          branchId: non_neg_integer(),
          postalCode: String.t() | nil,
          primaryEmailAddress: String.t(),
          primaryPhoneNumber: String.t(),
          primaryPhoneNumberCountryCallingCode: pos_integer(),
          cellPhoneNumber: String.t() | nil,
          cellPhoneNumberCountryCallingCode: integer(),
          countryCode: non_neg_integer(),
          howHeardOfId: non_neg_integer()
        }
  @spec create_employee(binary(), create_params()) ::
          {:ok, map()} | {:error, :unauthorized} | {:error, term()}
  def create_employee(access_token, body) do
    url = "#{get_base_url()}/Employees"
    encoded_body = Jason.encode!(body)

    # we want to return the whole response so we can save it in the `external_contact` field
    # %{"employeeId" => id} = Jason.decode!(body)
    url
    |> HTTPoison.post(encoded_body, get_headers(access_token, :post), @request_opts)
    |> handle_response(fn decoded_body -> {:ok, decoded_body} end)
  end

  @spec create_employee_message(binary(), binary(), integer(), binary()) ::
          {:ok, map()} | {:error, term()}
  def create_employee_message(access_token, employee_id, action_id, message_body) do
    url = "#{get_base_url()}/Employees/#{employee_id}/messages"

    params = %{
      message: message_body,
      linkedEntities: [],
      linkedDocumentIds: [],
      shouldLinkRelatedEntities: false,
      shouldLinkOriginsOneByOne: false,
      actionId: action_id
    }

    encoded_body = Jason.encode!(params)

    http_request_function = fn ->
      HTTPoison.post(url, encoded_body, get_headers(access_token, :post), @request_opts)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn decoded_body -> {:ok, decoded_body} end)
  end

  @spec get_employee(binary(), non_neg_integer()) :: {:ok, EmployeeDetail.t()} | {:error, term()}
  def get_employee(access_token, id) do
    url = "#{get_base_url()}/Employees/#{id}"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_employee_detail(body)} end)
  end

  @spec get_employee_eeo(binary(), non_neg_integer()) :: {:ok, EmployeeEeoDetail.t()} | {:error, term()}
  def get_employee_eeo(access_token, id) do
    url = "#{get_base_url()}/Employees/#{id}/eeo"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 2, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_employee_eeo_detail(body)} end)
  end

  @spec get_employee_custom_data(binary(), non_neg_integer()) ::
          {:ok, %{custom_data: [CustomData.t()], total: non_neg_integer()}}
          | {:error, term()}
  def get_employee_custom_data(access_token, id) do
    url = "#{get_base_url()}/Employees/#{id}/CustomData"

    http_request_function = fn ->
      HTTPoison.get(url, get_headers(access_token, :get), recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1500)
    |> handle_response(&Parser.parse_custom_data_set/1)
  end

  def create_contact_message(access_token, contact_id, action_id, message_body) do
    id = String.replace_prefix(contact_id, "contact-", "")
    url = "#{get_base_url()}/Contacts/#{id}/messages"

    params = %{
      message: message_body,
      linkedEntities: [],
      linkedDocumentIds: [],
      shouldLinkRelatedEntities: false,
      shouldLinkOriginsOneByOne: false,
      actionId: action_id
    }

    encoded_body = Jason.encode!(params)

    http_request_function = fn ->
      HTTPoison.post(url, encoded_body, get_headers(access_token, :post), @request_opts)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn decoded_body -> {:ok, decoded_body} end)
  end

  @spec get_tempwork_contact_custom_data(binary(), non_neg_integer()) ::
          {:ok, %{custom_data: [CustomData.t()], total: non_neg_integer()}}
          | {:error, term()}
  def get_tempwork_contact_custom_data(access_token, contact_id) do
    id = String.replace_prefix(contact_id, "contact-", "")
    url = "#{get_base_url()}/Contacts/#{id}/CustomData"

    http_request_function = fn ->
      HTTPoison.get(url, get_headers(access_token, :get), recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_custom_data_set/1)
  end

  @spec get_contact(binary(), integer()) :: {:ok, TempworkContactDetail.t()} | {:error, term()}
  def get_contact(access_token, contact_id) when is_integer(contact_id) do
    url = "#{get_base_url()}/Contacts/#{contact_id}"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_contact_detail(body)} end)
  end

  @spec get_contact(binary(), non_neg_integer()) :: {:ok, TempworkContactDetail.t()} | {:error, term()}
  def get_contact(access_token, contact_id) do
    id = String.replace_prefix(contact_id, "contact-", "")
    url = "#{get_base_url()}/Contacts/#{id}"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_contact_detail(body)} end)
  end

  def list_contacts(access_token, opts \\ []) do
    url = "#{get_base_url()}/Search/Contacts"
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    is_active = Keyword.get(opts, :is_active, true)

    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers, params: [take: limit, skip: offset, isActive: is_active], recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_contacts/1)
  end

  def get_contact_search_by_id(access_token, contact_id, opts \\ []) do
    url = "#{get_base_url()}/Search/Contacts"
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    is_active = Keyword.get(opts, :is_active, true)

    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers,
        params: [take: limit, skip: offset, isActive: is_active, contactId: contact_id],
        recv_timeout: 60_000
      )
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_contacts(body)} end)
  end

  def get_contact_contact_methods(access_token, contact_id) do
    url = "#{get_base_url()}/Contacts/#{contact_id}/contactMethods"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers, params: [take: 100, skip: 0, id: contact_id], recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(&Parser.parse_contact_contact_methods/1)
  end

  @spec list_employee_assignments(binary(), non_neg_integer(), [list_opt()]) ::
          {:ok, %{assignments: [EmployeeAssignment.t()], total: non_neg_integer()}}
          | {:error, term()}
  def list_employee_assignments(access_token, id, opts \\ []) do
    url = "#{get_base_url()}/Employees/#{id}/assignments"
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    is_active = Keyword.get(opts, :is_active, true)

    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers, params: [take: limit, skip: offset, isActive: is_active], recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_employee_assignments/1)
  end

  @spec get_employee_universal_phone(binary(), non_neg_integer()) :: {:ok, UniversalPhone.t()} | {:error, term()}
  def get_employee_universal_phone(access_token, phone) do
    url = "#{get_base_url()}/Search/UniversalPhone/?phone=#{phone}"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 2, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_universal_phone_list(body)} end)
  end

  @spec get_employee_universal_email(binary(), non_neg_integer()) :: {:ok, UniversalEmail.t()} | {:error, term()}
  def get_employee_universal_email(access_token, email) do
    url = "#{get_base_url()}/Search/UniversalEmail/?emailAddress=#{email}"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 2, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_universal_email_list(body)} end)
  end

  @spec get_employee_status(binary(), non_neg_integer()) :: {:ok, UniversalEmail.t()} | {:error, term()}
  def get_employee_status(access_token, employee_id) do
    url = "#{get_base_url()}/Employees/#{employee_id}/status"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 3, delay: 1000)
    |> handle_response(fn body -> {:ok, Parser.parse_employee_status(body)} end)
  end

  ##################
  # Advance Search #
  ##################

  @spec list_employee_columns(binary()) :: {:ok, map()} | {:error, term()}
  def list_employee_columns(access_token) do
    url = "#{get_base_url()}/search/#{@employee_origin_type_id}/columns"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn response -> {:ok, response} end)
  end

  @spec list_employees_advance_details(binary(), list()) :: {:ok, map()} | {:error, term()}
  def list_employees_advance_details(access_token, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    returned_columns = Keyword.get(opts, :columns, [])

    url = "#{get_base_url()}/search/#{@employee_origin_type_id}"
    headers = get_headers(access_token, :post)
    columns = prepare_employee_query(returned_columns, limit, offset)

    url
    |> HTTPoison.post(columns, headers, @advance_request_opts)
    |> handle_response(&Parser.parse_advance_search/1)
  end

  def list_todays_employees(access_token) do
    url = "#{get_base_url()}/search/#{@employee_origin_type_id}"
    headers = get_headers(access_token, :post)
    columns = prepare_todays_employee_query()

    url
    |> HTTPoison.post(columns, headers, @advance_request_opts)
    |> handle_response(&Parser.parse_todays_employees/1)
  end

  defp prepare_employee_query(returned_columns, limit, offset) do
    Jason.encode!(
      %{
        "searchCriteria" => %{
          "rootGroup" => %{
            "condition" => 0,
            "not" => false,
            "rules" => [%{"columnId" => "f7daae6e-91c2-411e-9d94-2c6f17725eb4", "operatorId" => 20, "values" => nil}]
          },
          "returnColumnIds" => returned_columns
        },
        "sortByColumns" => [
          # last_name
          %{"columnId" => "d14bf8a7-ba46-401d-8b7c-a264b117030a", "isDescending" => false},
          # first_name
          %{"columnId" => "2a9ab5d8-a9d8-49c8-ae1c-17737471f860", "isDescending" => false}
        ],
        "ignoreCachedResults" => true,
        "skip" => offset,
        "take" => limit
      },
      escape: :unicode_safe
    )
  end

  defp prepare_todays_employee_query do
    today_date =
      Date.utc_today()
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      |> DateTime.to_iso8601()

    Jason.encode!(
      %{
        "searchCriteria" => %{
          "rootGroup" => %{
            "condition" => 0,
            "not" => false,
            "rules" => [
              %{"columnId" => "f7daae6e-91c2-411e-9d94-2c6f17725eb4", "operatorId" => 20, "values" => nil},
              %{"columnId" => "20a9a451-8f4b-4cbb-9519-eda06857b891", "operatorId" => 3, "values" => [today_date]}
            ]
          },
          "returnColumnIds" => [
            "f7daae6e-91c2-411e-9d94-2c6f17725eb4",
            "20a9a451-8f4b-4cbb-9519-eda06857b891",
            "d14bf8a7-ba46-401d-8b7c-a264b117030a",
            "2a9ab5d8-a9d8-49c8-ae1c-17737471f860"
          ]
        },
        "sortByColumns" => [
          # last_name
          %{"columnId" => "d14bf8a7-ba46-401d-8b7c-a264b117030a", "isDescending" => false},
          # first_name
          %{"columnId" => "2a9ab5d8-a9d8-49c8-ae1c-17737471f860", "isDescending" => false}
        ],
        "ignoreCachedResults" => true,
        "skip" => 0,
        "take" => 1000
      },
      escape: :unicode_safe
    )
  end
end
