defmodule Sync.Clients.Whippy.Users do
  @moduledoc false

  import Sync.Clients.Whippy.Common
  import Sync.Clients.Whippy.Parser, only: [parse: 2]

  alias Sync.Clients.Whippy.Model.User

  require Logger

  @type state() :: :enabled | :disabled | :invited | :archived
  @type role() :: :admin | :user
  @type list_users_opt() ::
          {:name, String.t()}
          | {:email, String.t()}
          | {:role, role()}
          | {:state, state()}
          | {:limit, non_neg_integer()}
          | {:offset, non_neg_integer()}
  @spec list_users(binary(), [list_users_opt()]) ::
          {:ok, %{users: [User.t()], total: non_neg_integer()}} | {:error, term()}
  def list_users(api_key, opts \\ []) do
    url = "#{get_base_url()}/v1/users"

    api_key
    |> request(:get, url, "", params: opts)
    |> handle_response(&parse(&1, {:users, :user}))
  end
end
