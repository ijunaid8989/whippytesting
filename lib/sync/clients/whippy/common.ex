defmodule Sync.Clients.Whippy.Common do
  @moduledoc """
  Common functions for the Whippy API.
  """

  alias Sync.Utils.Http.Retry

  require Logger

  @rate_limit_header "X-RateLimit-Remaining-Interval-Milliseconds"

  def get_headers(api_key) when is_binary(api_key) do
    [
      {"X-WHIPPY-KEY", api_key},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  def get_headers(invalid_api_key) do
    Logger.error("Invalid API key provided to Whippy get_headers: #{inspect(invalid_api_key)}")
    []
  end

  def get_base_url do
    Application.get_env(:sync, :whippy_api)
  end

  @doc """
  The function makes a request to the Whippy API. It takes an API key, a method, a URL, a string or map body, and request options.

  It retries the request if the response status code is 429 (rate limit exceeded) and the delay is taken from the
  rate limit header. The request is retried a maximum of 3 times.

  All requests to Whippy should be made using this function.

  ## Examples

    iex> Whippy.Common.request("124ad2e", :get, "http://example.com")
    {:ok, %HTTPoison.Response{status_code: 200, body: body}}

    iex> Whippy.Common.request("124ad2e", :get, "http://example.com", "", [recv_timeout: 60_000])
    {:ok, %HTTPoison.Response{status_code: 200, body: body}}

    iex> Whippy.Common.request("124ad2e", :post, "http://example.com", %{key: "value"})
    {:ok, %HTTPoison.Response{status_code: 200, body: body}}

   iex> Whippy.Common.request("124ad2e", :post, "http://example.com", %{key: "value"}, [recv_timeout: 60_000])
    {:error, %HTTPoison.Error{reason: reason}}

  """
  def request(api_key, method, url, body \\ "", request_opts \\ []) do
    retry_opts = [
      max_attempts: 3,
      retry_status_codes: [429],
      delay_opts: [header: @rate_limit_header, granularity: :millisecond]
    ]

    body = if method in [:post, :put] && is_map(body), do: Jason.encode!(body), else: body

    http_request_function = fn ->
      HTTPoison.request(method, url, body, get_headers(api_key), request_opts)
    end

    Retry.request(http_request_function, retry_opts)
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}) when status_code in 200..202 do
    {:ok, Jason.decode!(body)}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}) do
    Logger.error("[Whippy] Error when making request in Whippy: status code #{status_code} with body #{inspect(body)}")

    {:error, %{status_code: status_code, body: inspect(body)}}
  end

  def handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
  end

  def handle_response(error) do
    {:error, error}
  end

  @doc """
  A helper function to handle the response from HTTPoison. It takes a success callback function that will be called if the response is successful.
  The success callback function should take a single argument, which is the decoded response body.

  ## Examples

    iex> Whippy.Common.handle_response({:ok, %HTTPoison.Response{status_code: 200, body: "{}"}}, fn body -> body end)
    %{}

    iex> Whippy.Common.handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body}}, fn body -> body end)
    {:error, %{status_code: 404, body: body}}

    iex> Whippy.Common.handle_response({:error, %HTTPoison.Error{reason: reason}})
    {:error, reason}
  """
  @spec handle_response({:ok, HTTPoison.Response.t()}, (term -> term)) :: term() | {:error, term()}
  def handle_response(http_poison_response, success_callback) do
    case handle_response(http_poison_response) do
      {:ok, response} -> success_callback.(response)
      {:error, error} -> {:error, error}
    end
  end
end
