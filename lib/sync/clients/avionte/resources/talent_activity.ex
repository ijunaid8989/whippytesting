defmodule Sync.Clients.Avionte.Resources.TalentActivity do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  @doc """
  Creates a new talent activity in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'
    - `opts` - The options for creating a talent activity.
      - `talent_id` - The ID of the talent.
      - `body` - The parameters for creating a talent activity in a map.
        - `notes` - The notes for the activity.
        - `typeId` - The ID of the activity type e.g -95 for `Daily SMS Summary`
        - `activityDate` - The date of the activity as date-time string e.g "2021-09-01T00:00:00"
        - `userId` - The ID of the user who logged the activity.

  ## Returns
    - `{:ok, TalentActivity.t()}` - The created talent activity.
    - `{:error, term()}` - The error message.
  """
  @type create_params :: %{notes: String.t(), typeId: neg_integer(), activityDate: String.t(), userId: non_neg_integer()}
  @type create_opts :: [talent_id: non_neg_integer(), body: create_params()]
  @spec create_talent_activity(String.t(), String.t(), String.t(), create_opts()) ::
          {:ok, TalentActivity.t()} | {:error, term()}
  def create_talent_activity(api_key, bearer_token, tenant, opts) do
    opts = Keyword.validate!(opts, [:talent_id, :body])
    url = get_base_url() <> "/talent/#{opts[:talent_id]}/activity"
    headers = get_headers(api_key, bearer_token, tenant)

    opts[:body]
    |> Jason.encode!()
    |> then(&HTTPoison.post(url, &1, headers, recv_timeout: 30_000))
    |> handle_response(&parse(&1, :talent_activity))
  end

  @doc """
  Lists the talent activity types in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'

  ## Returns
    - `{:ok, [sync_activity_type()]}` - The list of talent activity types.
    - `{:error, term()}` - The error message.
  """
  @type sync_activity_type :: %{activity_type_id: integer(), name: String.t()}
  @spec list_talent_activity_types(String.t(), String.t(), String.t()) :: {:ok, [sync_activity_type()]} | {:error, term()}
  def list_talent_activity_types(api_key, bearer_token, tenant) do
    url = get_base_url() <> "/talent/activity-types"
    headers = get_headers(api_key, bearer_token, tenant)

    url
    |> HTTPoison.get(headers, recv_timeout: 30_000)
    |> handle_response(&parse(&1, :talent_activity_types))
  end
end
