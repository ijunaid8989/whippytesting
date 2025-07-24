defmodule Sync.Clients.Tempworks.Resources.Webhook do
  @moduledoc false

  import Sync.Clients.Tempworks.Common

  alias Sync.Clients.Tempworks.Parser
  alias Sync.Utils.Http.Retry

  require Logger

  @request_opts [recv_timeout: 60_000]

  @type subscribe_topic_response_map :: %{
          subscriptionId: integer()
        }
  @type subscriptions_list_response_map :: %{
          subscriptions: [
            %{
              subscriptionId: integer(),
              clientId: binary(),
              tenantName: binary(),
              callbackUrl: binary(),
              callbackUrlIsSensitive: boolean(),
              httpMethod: binary(),
              httpHeaderName: binary(),
              httpHeaderValue: binary(),
              httpHeaderValueIsSensitive: boolean(),
              srIdent: integer(),
              created: binary(),
              lastModified: binary(),
              isActive: boolean()
            }
          ]
        }
  @spec list_subscriptions(binary()) :: {:ok, subscriptions_list_response_map} | {:error, term()}
  def list_subscriptions(access_token) do
    url = "#{get_webhook_base_url()}/Subscriptions"
    headers = get_headers(access_token, :get)

    http_request_function = fn ->
      HTTPoison.get(url, headers, @request_opts)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_subscriptions/1)
  end

  @spec subscribe_topic(binary(), map()) :: {:ok, subscribe_topic_response_map} | {:error, term()}
  def subscribe_topic(access_token, body) do
    url = "#{get_webhook_base_url()}/Subscriptions"
    headers = get_headers(access_token, :post)
    encoded_body = Jason.encode!(body)

    http_request_function = fn ->
      HTTPoison.post(url, encoded_body, headers, @request_opts)
    end

    http_request_function
    |> Retry.request(max_attempts: 3)
    |> handle_response(&Parser.parse_new_subscriptions/1)
  end
end
