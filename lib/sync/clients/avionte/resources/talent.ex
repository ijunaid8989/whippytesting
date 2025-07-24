defmodule Sync.Clients.Avionte.Resources.Talent do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  alias Sync.Clients.Avionte.Model.Talent
  alias Sync.Clients.Avionte.Model.TalentRequirement
  alias Sync.Utils.Http.Retry

  @doc """
  Lists the IDs of talents in Avionte.

  It returns a list of integers representing the IDs of talents.
  `page` and `page_size` are optional parameters and default to 1 and 50, respectively.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'
    - `opts` - The options for listing talent IDs.
      - `limit` - The number of talents to return.
      - `offset` - The number of talents to skip.

  ## Returns
    - `{:ok, [non_neg_integer()]}` - The list of talent IDs.
    - `{:error, term()}` - The error message.
  """
  @type list_talent_ids_opts :: [limit: non_neg_integer(), offset: non_neg_integer()]
  @spec list_talent_ids(String.t(), String.t(), String.t(), list_talent_ids_opts()) ::
          {:ok, [non_neg_integer()]} | {:error, term()}
  def list_talent_ids(api_key, bearer_token, tenant, opts \\ []) do
    opts = Keyword.validate!(opts, limit: 50, offset: 0)
    {page, page_size} = page_and_page_size(opts)

    url = "#{get_base_url()}/talents/ids/#{page}/#{page_size}/"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :talent_ids))
  end

  @doc """
  Lists the talents in Avionte with the given IDs.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `opts` - The options for listing talents.
      - `talent_ids` - The IDs of the talents to list.

  ## Returns
    - `{:ok, [Talent.t()]}` - The list of talents.
    - `{:error, term()}` - The error message.
  """
  @type opts :: [talent_ids: [non_neg_integer()]]
  @type contact_map :: %{
          external_contact_id: String.t(),
          phone: String.t(),
          name: String.t(),
          email: String.t(),
          birth_date: String.t(),
          external_contact: Talent.t()
        }
  @spec list_talents(String.t(), String.t(), String.t(), opts()) :: {:ok, [contact_map()]} | {:error, term()}
  def list_talents(api_key, bearer_token, tenant, opts) do
    talent_ids = Keyword.get(opts, :talent_ids)

    url = "#{get_base_url()}/talents/multi-query"
    headers = get_headers(api_key, bearer_token, tenant)
    http_request_function = fn -> HTTPoison.post(url, Jason.encode!(talent_ids), headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :talents))
  end

  @doc """
  Makes a request to create a talent in Avionte.

  Note:
  To send a valid request, the request body must contain the following parameters:
    - RepresentativeUser
    - Origin
    - If useNewTalentRequirements=true: parameters that are required for your tenant (obtained with get_talent_requirement/3);
    - If useNewTalentRequirements=false: firstName, lastName, and emailAddress.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'.
    - `body` - The parameters to create a talent.
      - `mobilePhone` - The mobile phone number of the talent.
      - `firstName` - The first name of the talent.
      - `lastName` - The last name of the talent.
      - `emailAddress` - The email address of the talent.
      - `origin` - The origin of the talent e.g 'whippy'.
      - `representativeUser` - The ID of the representative user of the talent.

  ## Returns
    - `{:ok, create_talent_response_map()}` - The created talent.
    - `{:error, term()}` - The error message.
  """
  @type create_talent_params_map :: %{
          mobilePhone: String.t(),
          firstName: String.t(),
          lastName: String.t(),
          emailAddress: String.t(),
          origin: String.t(),
          representativeUser: String.t()
        }
  @spec create_talent(String.t(), String.t(), String.t(), create_talent_params_map()) ::
          {:ok, contact_map()} | {:error, term()}
  def create_talent(api_key, bearer_token, tenant, body) do
    url = "#{get_base_url()}/talent?useNewTalentRequirements=false"
    headers = get_headers(api_key, bearer_token, tenant)

    http_request_function = fn -> HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :talent))
  end

  @doc """
  Gets a map representing what fields are required to create a talent in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer (access) token.
    - `tenant` - The tenant provided by Avionte e.g 'eov'.

  ## Returns
    - `{:ok, map()}` - The map representing the required fields.
    - `{:error, term()}` - The error message.
  """
  @spec get_talent_requirement(String.t(), String.t(), String.t()) :: {:ok, TalentRequirement.t()} | {:error, term()}
  def get_talent_requirement(api_key, bearer_token, tenant) do
    url = "#{get_base_url()}/talent-requirement"
    headers = get_headers(api_key, bearer_token, tenant)

    http_request_function = fn -> HTTPoison.get(url, headers, recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(&parse(&1, :talent_requirement))
  end
end
