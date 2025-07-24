defmodule Sync.Clients.Crelate.Common do
  @moduledoc """
  A list of common functions that the api shares.
  """

  alias Sync.Utils.Http.Retry

  require Logger

  def handle_http_get_request_and_response(url) do
    http_request_function = fn ->
      HTTPoison.get(url, recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, body} end)
  end

  def handle_http_get_request_and_response(url, limit, offset) do
    http_request_function = fn ->
      HTTPoison.get(url, [], params: [limit: limit, offset: offset], recv_timeout: 60_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 1000)
    |> handle_response(fn body -> {:ok, body} end)
  end

  def handle_http_post_request_and_response(url, body) do
    http_request_function = fn -> HTTPoison.post(url, Jason.encode!(body), recv_timeout: 30_000) end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response(fn decoded_body -> {:ok, decoded_body} end)
  end

  def get_base_url(true) do
    Application.get_env(:sync, :crelate_api)
  end

  def get_base_url(false) do
    Application.get_env(:sync, :crelate_sandbox_api)
  end

  @doc """
  Handles the response from the Crelate API.
  If the response is successful (status code is 200 or 201), the response body will be decoded and passed
  to the success_callback function.
  If the response is an error, it will return the error.

  ## Arguments
    - `response` - The HTTPoison response tuple that is returned after a request to the Avionte API.
    - `success_callback` - The function to call if the response is successful.

  ## Returns
    - `{:ok, term()}` - The result of the success_callback function.
    - `{:error, term()}` - The error tuple.
  """
  @type httpoison_response :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  @type success_callback :: (map() -> {:ok, any()})
  @spec handle_response(httpoison_response, success_callback) ::
          {:ok, term()} | {:error, :unauthorized} | {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}}, success_callback) when code in 200..201,
    do: body |> Jason.decode!() |> success_callback.()

  def handle_response({:ok, %HTTPoison.Response{status_code: 401}}, _success_callback) do
    {:error, :unauthorized}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}, _success_callback)
      when status_code in 400..422 do
    Logger.error("[Crelate] HTTP error, status code: #{status_code}, body: #{inspect(body)}")
    {:error, "HTTP error, status code: #{status_code}", Jason.decode!(body)}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}, _success_callback)
      when status_code == 500 do
    Logger.error("[Crelate] HTTP error, status code: #{status_code}, body: #{inspect(body)}")
    {:error, "HTTP error, status code: #{status_code}", Jason.decode!(body)}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: nil, body: body}}, _success_callback) do
    Logger.error("[Crelate] HTTP error, status code: nil, body: #{inspect(body)}")
    {:error, "HTTP error, status code: nil"}
  end

  def handle_response({:error, %HTTPoison.Error{} = error}, _success_callback), do: {:error, error}

  def handle_response(error) do
    Logger.error("[Crelate] Unhandled API error: #{inspect(error)}")
    {:error, error}
  end
end
