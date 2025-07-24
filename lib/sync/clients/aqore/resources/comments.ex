defmodule Sync.Clients.Aqore.Resources.Comments do
  @moduledoc false

  import Sync.Clients.Aqore.Common
  import Sync.Clients.Aqore.Parser

  alias Sync.Utils.Http.Retry

  require Logger

  @doc """
  Creates a comment in Aqore.

  ## Arguments
    - `map` - The access token and base URL for authentication.
    - `payload` - A map containing the comment data.

  ## Returns
    - `{:ok, comment}` - The created comment.
    - `{:error, error}` - An error occurred during the creation process.

  ## Examples

    iex> payload = %{content: "This is a comment", user_id: 123}
    iex> Sync.Clients.Aqore.Resources.Comments.create_comment("valid_access_token", payload)
    {:ok, %{id: 456, content: "This is a comment", user_id: 123}}

    iex> Sync.Clients.Aqore.Resources.Comments.create_comment("invalid_token", %{})
    {:error, "Invalid access token"}

  """
  @type comment_payload :: %{content: String.t(), user_id: non_neg_integer()}
  @type create_comment_result :: {:ok, map()} | {:error, String.t()}
  @spec create_comment(%{}, comment_payload()) :: create_comment_result()
  def create_comment(%{"base_api_url" => base_api_url, "access_token" => access_token}, payload) do
    headers = get_headers(access_token)
    url = "#{base_api_url}/api/common/data"

    http_request_function = fn ->
      HTTPoison.post(url, Jason.encode!(payload), headers, recv_timeout: 300_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response()
    |> case do
      {:ok, body} -> parse(body, :comment)
      {:error, error} -> parse!(error, :error)
    end
  end
end
