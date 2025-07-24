defmodule Sync.Clients.Aqore.Common do
  @moduledoc false
  require Logger

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}) when status_code in 200..201 do
    {:ok, Jason.decode!(body)}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: error_body}})
      when status_code in 400..422 do
    {:error, Jason.decode!(error_body)}
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: _any_other_status_code, body: body}}) do
    {:error, body}
  end

  def handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
  end

  def handle_response(error) do
    metadata = [integration_client: "Aqore", error: inspect(error)]
    Logger.error("Unhandled API error", metadata)
    {:error, error}
  end

  def get_headers(access_token) when is_binary(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]
  end

  def get_headers(invalid_input) do
    metadata = [integration_client: "Aqore", error: invalid_input]
    Logger.error("Invalid input for get_headers", metadata)
    []
  end
end
