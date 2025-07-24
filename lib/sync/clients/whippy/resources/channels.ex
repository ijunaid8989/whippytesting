defmodule Sync.Clients.Whippy.Channels do
  @moduledoc false

  import Sync.Clients.Whippy.Common
  import Sync.Clients.Whippy.Parser, only: [parse: 2]

  alias Sync.Clients.Whippy.Model.Channel

  require Logger

  @spec list_channels(binary()) :: {:ok, %{channels: [Channel.t()]}} | {:error, term()}
  def list_channels(api_key) do
    url = "#{get_base_url()}/v1/channels"

    api_key
    |> request(:get, url)
    |> handle_response(&parse(&1, {:channels, :channel}))
  end

  @spec get_channel(binary(), binary()) :: {:ok, Channel.t()} | {:error, term()}
  def get_channel(api_key, id) do
    url = "#{get_base_url()}/v1/channels/#{id}"

    api_key
    |> request(:get, url)
    |> handle_response(&parse(&1, :channel))
  end
end
