defmodule Sync.Clients.Hubspot do
  @moduledoc false
  alias Sync.Authentication.Hubspot, as: Auth
  alias Sync.Clients.Hubspot.ClientException
  alias Sync.Clients.Hubspot.Resources.Activity
  alias Sync.Clients.Hubspot.Resources.Contact
  alias Sync.Clients.Hubspot.Resources.Owner

  defdelegate pull_contacts(client, cursor \\ ""), to: Contact
  defdelegate push_contacts(client, contacts), to: Contact
  defdelegate search_contacts_by_id(client, ids), to: Contact
  defdelegate push_activities(client, activities), to: Activity
  defdelegate pull_owners(client, cursor \\ ""), to: Owner

  @spec get_client(any()) ::
          (:delete | :get | :head | :options | :patch | :post | :put, binary(), any(), any() ->
             any())
  def get_client(integration) do
    fn method, path, body, should_refresh_token ->
      request(integration, method, path, body, should_refresh_token)
    end
  end

  defp request(integration, method, path, body, should_refresh_token) do
    integration = prepare_integration(integration, should_refresh_token)

    headers = [
      {"Authorization", "Bearer #{integration.authentication["access_token"]}"},
      {"Content-Type", "application/json"}
    ]

    retry_callback = fn should_refresh_token ->
      request(integration, method, path, body, should_refresh_token)
    end

    method
    |> HTTPoison.request(
      Application.get_env(:sync, :hubspot_api) <> path,
      Jason.encode!(body),
      headers
    )
    |> process_response(retry_callback)
  end

  defp prepare_integration(integration, true) do
    integration
    |> Auth.refresh_token!()
    |> cache_integration()
  end

  defp prepare_integration(integration, false) do
    get_cached_integration(integration) || integration
  end

  defp cache_integration(integration) do
    :ets.insert(:integrations, {integration.id, integration})
    integration
  end

  defp get_cached_integration(integration) do
    case :ets.lookup(:integrations, integration.id) do
      [] -> nil
      [{_, integration}] -> integration
    end
  end

  # Successful request
  defp process_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, _retry_callback)
       when status >= 200 and status < 300 do
    Jason.decode!(body)
  end

  # Handle expired token
  defp process_response({:ok, %HTTPoison.Response{status_code: 401, body: body}}, retry_callback) do
    decoded_body = Jason.decode!(body)

    case decoded_body do
      %{"category" => "EXPIRED_AUTHENTICATION"} -> retry_callback.(true)
      _ -> raise decoded_body["message"]
    end
  end

  # Handle rate limit
  defp process_response({:ok, %HTTPoison.Response{status_code: 429, headers: headers}}, retry_callback) do
    :timer.sleep(get_remaining_rate_limit_time(headers))
    retry_callback.(false)
  end

  # Handle any other status
  defp process_response({:ok, %HTTPoison.Response{body: body}}, _retry_callback) do
    decoded_body = Jason.decode!(body)
    raise ClientException, message: decoded_body["message"]
  end

  # Handle general errors
  defp process_response({:error, %HTTPoison.Error{reason: reason}}, _retry_callback) do
    raise ClientException, message: reason
  end

  defp get_remaining_rate_limit_time(headers) do
    headers
    |> Map.new()
    |> Map.get("x-hubspot-ratelimit-secondly-remaining", "10")
    |> to_string()
    |> String.to_integer()
    |> Kernel.*(1000)
  end
end
