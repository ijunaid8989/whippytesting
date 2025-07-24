defmodule Sync.Clients.Tempworks.Resources.Branch do
  @moduledoc false
  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Model.Branch
  alias Sync.Clients.Tempworks.Parser

  @doc """
  List the branches tied to the organization. If no limit or offset is provided, we will default
  to an offset of 0 and a limit of 10.

  TempWorks have 2 endpoints that return a list of branches:
    - /Branches
    - /DataLists/branches

  They use the same type of auth but the first one returns 4 more fields: - 
  hierId, employer (string, not ID), distanceUnit, and distanceToLocation.

  Additionally, the second one accepts only 5 parameters: take, skip, active, restrictToWebPublicBranches, 
  and employerId.

  The first one has the same query parameters (with the detail of `active` being named `restrictToActiveBranches`),
  however, it also supports filters postalCode, latitude, longitude, and distanceUnitId.

  We will use the first one because of these details.
  """
  @type list_opt :: {:limit, non_neg_integer()} | {:offset, non_neg_integer()}
  @type response_map :: %{
          branches: [
            %{
              external_channel_id: binary(),
              external_channel: Branch.t()
            }
          ],
          total: non_neg_integer()
        }
  @spec list_branches(binary(), [list_opt()]) :: {:ok, response_map()} | {:error, term()}
  def list_branches(access_token, opts \\ []) do
    url = "#{get_base_url()}/Branches"
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    active = Keyword.get(opts, :active, true)

    # Note: Tempworks uses the terms take for limit and skip for offset
    url
    |> HTTPoison.get(get_headers(access_token, :get),
      params: [take: limit, skip: offset, restrictToActiveBranches: active],
      recv_timeout: 15_000
    )
    |> handle_response(&Parser.parse_branches/1)
  end
end
