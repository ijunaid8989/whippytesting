defmodule Sync.Clients.Aqore.Resources.Candidates do
  @moduledoc false
  import Sync.Clients.Aqore.Common
  import Sync.Clients.Aqore.Parser

  alias Sync.Utils.Http.Retry

  require Logger

  def list_candidates(details, limit, offset, sync) do
    payload =
      if sync == :daily_sync do
        %{
          "action" => "CandidateDataSync",
          "filters" => %{
            "source" => "Whippy"
          }
        }
      else
        %{
          "action" => "CandidateData",
          "filters" => %{
            "page" => ceil(offset / limit) + 1,
            "size" => limit,
            "source" => "Whippy"
          }
        }
      end

    list_candidate_data(details, payload)
  end

  defp list_candidate_data(%{"base_api_url" => base_api_url, "access_token" => access_token}, payload) do
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
            parse(body, :candidates)
        end

      {:error, error} ->
        parse!(error, :error)
    end
  end

  @doc """
  Creates a candidate in Aqore.

  ## Arguments
  - `candidate` - The candidate to create.
  - `map` - Contains access token and base URL to use for the request.

  ## Returns
  - `{:ok, Candidate.t()}` - The created candidate.
  - `{:error, term()}` - The error message.
  """
  def create_candidate(candidate, %{"base_api_url" => base_api_url, "access_token" => access_token}) do
    headers = get_headers(access_token)
    url = "#{base_api_url}/api/common/data"

    payload = %{
      "client" => "ZenopleHub",
      "company" => "AAA",
      "action" => "EntityCreate",
      "filters" => %{
        "entityType" => "Candidate",
        "source" => "Whippy",
        "fields" => candidate
      }
    }

    http_request_function = fn ->
      HTTPoison.post(url, Jason.encode!(payload), headers, recv_timeout: 300_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response()
    |> case do
      {:ok, body} -> parse(body, :new_candidate)
      {:error, error} -> parse!(error, :error)
    end
  end

  def search_candidate_by_phone(phone, %{"base_api_url" => base_api_url, "access_token" => access_token}) do
    headers = get_headers(access_token)
    url = "#{base_api_url}/api/common/data"

    payload = %{
      "action" => "PersonSearch",
      "filters" => %{
        "searchText" => phone,
        "searchType" => "phone",
        "source" => "Whippy"
      }
    }

    http_request_function = fn ->
      HTTPoison.post(url, Jason.encode!(payload), headers, recv_timeout: 300_000)
    end

    http_request_function
    |> Retry.request(max_attempts: 5, delay: 100)
    |> handle_response()
    |> case do
      {:ok, body} -> parse(body, :candidates)
      {:error, error} -> parse!(error, :error)
    end
  end
end
