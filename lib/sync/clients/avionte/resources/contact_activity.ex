defmodule Sync.Clients.Avionte.Resources.ContactActivity do
  @moduledoc false

  import Sync.Clients.Avionte.Common
  import Sync.Clients.Avionte.Parser, only: [parse: 2]

  @doc """
  Creates a new contact activity in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'
    - `opts` - The options for creating a contact activity.
      - `contact_id` - The ID of the contact.
      - `body` - The parameters for creating a contact activity in a map.
        - `notes` - The notes for the activity.
        - `typeId` - The ID of the activity type e.g -95 for `Daily SMS Summary`
        - `activityDate` - The date of the activity as date-time string e.g "2021-09-01T00:00:00"
        - `userId` - The ID of the user who logged the activity.

  ## Returns
    - `{:ok, ContactActivity.t()}` - The created contact activity.
    - `{:error, term()}` - The error message.
  """
  @type create_params :: %{notes: String.t(), typeId: neg_integer(), activityDate: String.t(), userId: non_neg_integer()}
  @type create_opts :: [contact_id: non_neg_integer(), body: create_params()]
  @spec create_contact_activity(String.t(), String.t(), String.t(), create_opts()) ::
          {:ok, ContactActivity.t()} | {:error, term()}
  def create_contact_activity(api_key, bearer_token, tenant, opts) do
    opts = Keyword.validate!(opts, [:contact_id, :body])
    url = get_base_url() <> "/contact/#{opts[:contact_id]}/activity"
    headers = get_headers(api_key, bearer_token, tenant)

    opts[:body]
    |> Jason.encode!()
    |> then(&HTTPoison.post(url, &1, headers, recv_timeout: 30_000))
    |> handle_response(&parse(&1, :contact_activity))
  end

  @doc """
  Lists the contact activity types in Avionte.

  ## Arguments
    - `api_key` - The Avionte API key.
    - `bearer_token` - The bearer token.
    - `tenant` - The tenant provided by Avionte e.g 'apitest'

  ## Returns
    - `{:ok, [sync_activity_type()]}` - The list of contact activity types.
    - `{:error, term()}` - The error message.
  """
  @type sync_activity_type :: %{activity_type_id: integer(), name: String.t()}
  @spec list_contact_activity_types(String.t(), String.t(), String.t()) ::
          {:ok, [sync_activity_type()]} | {:error, term()}
  def list_contact_activity_types(api_key, bearer_token, tenant) do
    url = get_base_url() <> "/contact/activity-types"
    headers = get_headers(api_key, bearer_token, tenant)

    url
    |> HTTPoison.get(headers, recv_timeout: 30_000)
    |> handle_response(&parse(&1, :contact_activity_types))
  end
end
