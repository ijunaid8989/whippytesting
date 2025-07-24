defmodule Sync.Utils.Http.Retry do
  @moduledoc """
  Retry HTTP requests with exponential backoff.
  """

  require Logger

  @default_opts [
    delay: 1000,
    max_attempts: 5,
    current_attempt: 1,
    success_status_codes: [200, 201, 202, 204, 400, 403, 404],
    retry_status_codes: [],
    delay_opts: []
  ]

  @type http_poison_tuple :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  @type request_func :: (-> {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()})
  @type opts_map :: %{
          delay: non_neg_integer(),
          max_attempts: non_neg_integer(),
          current_attempt: non_neg_integer(),
          success_status_codes: [non_neg_integer()],
          retry_status_codes: [non_neg_integer()],
          delay_opts: [header: binary(), granularity: atom()] | []
        }

  @doc """
  Retries an HTTP request in case of failure or timeout. The request is retried with exponential backoff starting
  from the delay provided in the options and doubling with each attempt. In case delay_opts are provided, the delay
  is calculated based on the value in the header specified in the delay_opts.

  ## Arguments
    - `http_request_function` - The function that makes the HTTP request.
    - `opts` - A keyword list of options for retrying the request.
      - `delay` - The delay between attempts in milliseconds, which doubles with each attempt. Default is 1000ms.
      - `max_attempts` - The maximum number of attempts to make. Default is 5.
      - `current_attempt` - The current attempt number. Default is 1.
      - `success_status_codes` - The list of status codes that are considered successful. Default is [200, 201, 202, 204].
      - `retry_status_codes` - The list of status codes that should be retried. Default is an empty list.
      - `delay_opts` - A keyword list of options for calculating the delay between attempts.
        - `header` - The header name to look for in the response headers. Default is an empty list.
        - `granularity` - The granularity of the value in the header (either :second or :millisecond)

  ## Returns
    - `{:ok, HTTPoison.Response.t()}` - The successful response.
    - `{:error, HTTPoison.Error.t()}` - The error response.

  ## Examples
    iex> http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end
    iex> Retry.request(http_request_function)
    ie> {:ok, %HTTPoison.Response{status_code: 200, body: "Hello, world!"}}
  """
  @spec request(request_func, Keyword.t()) :: http_poison_tuple
  def request(http_request_function, opts \\ []) do
    opts = enforce_opts(opts)
    request(http_request_function.(), http_request_function, opts)
  end

  @spec request(http_poison_tuple, request_func, opts_map) :: http_poison_tuple
  defp request({:ok, %HTTPoison.Response{status_code: status_code} = response}, request_func, opts) do
    %{
      success_status_codes: success_codes,
      retry_status_codes: retry_codes,
      current_attempt: current_attempt,
      max_attempts: max_attempts
    } =
      opts

    if should_retry?(status_code, success_codes, retry_codes) do
      %HTTPoison.Request{method: method, url: url} = Map.get(response, :request)

      if current_attempt >= max_attempts do
        Logger.error("""
        Received #{status_code} response from #{method} #{url} (attempt #{current_attempt}/#{max_attempts}). Request failed after #{max_attempts} attempts.
        """)

        {:ok, response}
      else
        delay = calculate_delay(opts, response)

        Logger.info("""
        Received #{status_code} response from #{method} #{url} (attempt #{current_attempt}/#{max_attempts}). Retrying in #{delay}ms.
        """)

        Process.sleep(delay)

        request(request_func.(), request_func, increment_opts(opts))
      end
    else
      {:ok, response}
    end
  end

  defp request({:error, %HTTPoison.Error{id: id, reason: reason}} = response_tuple, request_func, opts) do
    %{current_attempt: current_attempt, max_attempts: max_attempts, delay: delay} = opts

    if current_attempt >= max_attempts do
      Logger.error("""
      HTTP request #{id} failed with reason: #{reason} (attempt #{current_attempt}/#{max_attempts}). Request failed after #{max_attempts} attempts.
      """)

      response_tuple
    else
      Logger.info("""
      HTTP request #{id} failed with reason: #{reason} (attempt #{current_attempt}/#{max_attempts}). Retrying request in #{delay}ms.
      """)

      Process.sleep(delay)

      request(request_func.(), request_func, increment_opts(opts))
    end
  end

  defp request(response, _request_func, _opts), do: response

  # Validates the options for retrying the request.
  # Raises an ArgumentError if unknown options are provided or if the values of the options are invalid.
  @spec enforce_opts(Keyword.t()) :: opts_map
  defp enforce_opts(opts) do
    opts
    |> Keyword.validate!(@default_opts)
    |> Map.new(fn
      {:max_attempts, value} when is_integer(value) -> {:max_attempts, value}
      {:current_attempt, value} when is_integer(value) -> {:current_attempt, value}
      {:delay, value} when is_integer(value) -> {:delay, value}
      {:success_status_codes, value} when is_list(value) -> {:success_status_codes, value}
      {:retry_status_codes, value} when is_list(value) -> {:retry_status_codes, value}
      {:delay_opts, []} -> {:delay_opts, []}
      {:delay_opts, value} when is_list(value) -> {:delay_opts, enforce_delay_opts(value)}
      {key, value} -> raise ArgumentError, "Invalid option value #{inspect(value)} for key :#{key}."
    end)
  end

  # Validates the delay_opts for the request.
  # Raises an ArgumentError if unknown options are provided, if the values of the options are invalid or if required keys are missing.
  defp enforce_delay_opts(opts) do
    opts
    |> validate_keys_present!([:header, :granularity])
    |> Enum.map(fn
      {:header, value} when is_binary(value) -> {:header, value}
      {:granularity, value} when value in [:second, :millisecond] -> {:granularity, value}
      {key, value} -> raise ArgumentError, "Invalid option value #{inspect(value)} for key :#{key}."
    end)
  end

  def validate_keys_present!(opts, required_keys) do
    if Enum.all?(required_keys, &Keyword.has_key?(opts, &1)),
      do: opts,
      else: raise(ArgumentError, "Missing required keys: #{inspect(required_keys -- Keyword.keys(opts))}")
  end

  # Increments the current_attempt and delay options for the next request attempt.
  @spec increment_opts(opts_map) :: opts_map
  defp increment_opts(opts) do
    opts
    |> Map.update!(:current_attempt, &(&1 + 1))
    |> Map.update!(:delay, &(&1 * 2))
  end

  defp should_retry?(status_code, success_codes, [] = _retry_codes), do: status_code not in success_codes
  defp should_retry?(status_code, _success_codes, retry_codes), do: status_code in retry_codes

  defp calculate_delay(%{delay_opts: [], delay: delay}, _response), do: delay

  defp calculate_delay(%{delay_opts: opts, delay: fallback_delay}, response) do
    header = String.downcase(opts[:header])
    granularity = opts[:granularity]

    %HTTPoison.Response{headers: headers} = response

    with {_, value} <- List.keyfind(headers, header, 0),
         {value, _} <- Integer.parse(value) do
      value * granularity_multiplier(granularity)
    else
      _error -> fallback_delay
    end
  end

  defp granularity_multiplier(:second), do: 1000
  defp granularity_multiplier(:millisecond), do: 1
end
