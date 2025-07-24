defmodule Sync.Clients.Tempworks.Resources.DataList do
  @moduledoc false
  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Parser

  @doc """
  Lists the active message actions tied to an organization.

  This endpoint supports specifying whether to return active or inactive message actions, as well as
  limiting and offsetting the results, but we will default to active and no limit or offset.
  """
  @type list_opt :: {:active, boolean()}
  @spec list_message_actions(binary(), [list_opt()]) :: term()
  def list_message_actions(access_token, opts \\ []) do
    url = "#{get_base_url()}/DataLists/messageActions"
    active = Keyword.get(opts, :active, true)

    url
    |> HTTPoison.get(get_headers(access_token, :get),
      params: [active: active],
      recv_timeout: 15_000
    )
    |> handle_response(&Parser.parse_message_actions/1)
  end
end
