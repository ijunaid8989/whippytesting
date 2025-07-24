defmodule Sync.Authentication.Whippy do
  @moduledoc """
  Handles authentication with the Whippy API.
  """

  alias Sync.Integrations.Integration

  def get_api_key(%Integration{authentication: %{"whippy_api_key" => api_key}}) when is_binary(api_key) do
    {:ok, api_key}
  end

  def get_api_key(_integration), do: {:error, "Invalid or missing Whippy API key"}
end
