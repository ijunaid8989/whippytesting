defmodule Sync.Clients.Tempworks.Common do
  @moduledoc """
  A list of common functions that the api shares.
  """

  require Logger

  @spec get_headers(binary(), :get | :post) :: list()
  def get_headers(bearer_token, :get) do
    [
      {"Authorization", "Bearer " <> bearer_token},
      {"Accept", "application/json"}
    ]
  end

  def get_headers(bearer_token, :post) do
    [
      {"Authorization", "Bearer " <> bearer_token},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  def get_base_url, do: Application.get_env(:sync, :tempworks_api)
  def get_webhook_base_url, do: Application.get_env(:sync, :tempworks_webhook_api)

  @doc """
  Handles the response from the Tempworks API.
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

  # Explicitly clause for tempworks webhooks
  def handle_response(
        {:ok,
         %HTTPoison.Response{status_code: 404, request_url: "https://webhooks-api.ontempworks.com/api/Subscriptions"}},
        _success_callback
      ) do
    {:ok, []}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, _success_callback) do
    Logger.error("[TempWorks] HTTP error, status code: #{status}, body: #{inspect(body)}")

    {:error, "HTTP error, status code: #{status}, body: #{inspect(body)}"}
  end

  def handle_response({:error, %HTTPoison.Error{} = error}, _success_callback), do: {:error, error}
end
