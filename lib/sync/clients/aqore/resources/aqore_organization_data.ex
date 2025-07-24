defmodule Sync.Clients.Aqore.Resources.AqoreOrganizationData do
  @moduledoc false
  import Sync.Clients.Aqore.Common
  import Sync.Clients.Aqore.Parser

  alias Sync.Utils.Http.Retry

  require Logger

  def list_organization_data(details, limit, offset, sync) do
    payload =
      if sync == :daily_sync do
        %{
          "action" => "OrganizationDataSync",
          "filters" => %{
            "source" => "Whippy"
          }
        }
      else
        %{
          "action" => "OrganizationData",
          "filters" => %{
            "page" => ceil(offset / limit) + 1,
            "size" => limit,
            "source" => "Whippy"
          }
        }
      end

    list_aqore_organization_data(details, payload)
  end

  defp list_aqore_organization_data(%{"base_api_url" => base_api_url, "access_token" => access_token}, payload) do
    headers = get_headers(access_token)
    url = "#{base_api_url}/api/common/data"

    http_request_function = fn ->
      HTTPoison.post(url, Jason.encode!(payload), headers, recv_timeout: 300_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response()
    |> case do
      {:ok, body} ->
        # Check if the response contains an error message
        case body do
          %{"message" => message} when is_binary(message) ->
            {:error, {"message", message}}

          _ ->
            parse(body, :organization_data)
        end

      {:error, error} ->
        parse!(error, :error)
    end
  end
end
