defmodule Sync.Utils.Http.RetryTest do
  use ExUnit.Case, async: false

  import Mock

  alias Sync.Utils.Http.Retry

  @moduletag capture_log: true

  describe "request/2" do
    test "retries an HTTP request if response status code is not in success status codes and no retry codes are provided" do
      with_mock HTTPoison, [], http_poison_mock() do
        http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end
        opts = [max_attempts: 3, delay: 1, current_attempt: 1]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.get(:_, :_, :_), 3)
      end
    end

    test "retries an HTTP request if response status code is in the list of retry status codes" do
      with_mock HTTPoison, [], http_poison_mock(429) do
        http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end
        opts = [max_attempts: 3, delay: 1, current_attempt: 1, retry_status_codes: [429]]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.get(:_, :_, :_), 3)
      end
    end

    test "does not retry an HTTP request if response status code is NOT in the list of retry status codes" do
      with_mock HTTPoison, [], http_poison_mock() do
        http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end
        opts = [max_attempts: 3, delay: 1, current_attempt: 1, retry_status_codes: [429]]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.get(:_, :_, :_), 1)
      end
    end

    test "retries an HTTP request if request has timed out" do
      with_mock HTTPoison, [], http_poison_mock() do
        http_request_function = fn -> HTTPoison.post("http://example.com", %{}, [], recv_timeout: 60_000) end
        opts = [max_attempts: 3, delay: 1, current_attempt: 1]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.post(:_, :_, :_, :_), 3)
      end
    end

    test "uses default opts when opts are not provided" do
      with_mocks([
        {HTTPoison, [], http_poison_mock()},
        {Process, [:passthrough], [sleep: fn _ -> :ok end]}
      ]) do
        http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end

        Retry.request(http_request_function)

        assert_called_exactly(HTTPoison.get(:_, :_, :_), 5)
      end
    end

    test "uses delay_opts to calculate delay" do
      with_mocks([
        {HTTPoison, [],
         get: fn _url, _headers ->
           {:ok,
            %HTTPoison.Response{
              status_code: 429,
              request: %HTTPoison.Request{url: "http://example.com", method: "get"},
              headers: [{"x-ratelimit-remaining-interval-milliseconds", "3000"}]
            }}
         end},
        {Process, [:passthrough],
         [
           sleep: fn delay_amount ->
             assert delay_amount == 3000
             :ok
           end
         ]}
      ]) do
        http_request_function = fn -> HTTPoison.get("http://example.com", []) end

        opts = [
          max_attempts: 3,
          retry_status_codes: [429],
          delay_opts: [header: "X-RateLimit-Remaining-Interval-Milliseconds", granularity: :millisecond]
        ]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.get(:_, :_), 3)
      end
    end

    test "fallbacks to the default delay when the header, defined in delay_opts, has an invalid value" do
      with_mocks([
        {HTTPoison, [],
         get: fn _url, _headers ->
           {:ok,
            %HTTPoison.Response{
              status_code: 429,
              request: %HTTPoison.Request{url: "http://example.com", method: "get"},
              headers: [{"x-ratelimit-remaining-interval-milliseconds", "not_a_number"}]
            }}
         end},
        {Process, [:passthrough],
         [
           sleep: fn delay_amount ->
             assert delay_amount == 1000
             :ok
           end
         ]}
      ]) do
        http_request_function = fn -> HTTPoison.get("http://example.com", []) end

        opts = [
          max_attempts: 2,
          retry_status_codes: [429],
          delay_opts: [header: "X-RateLimit-Remaining-Interval-Milliseconds", granularity: :millisecond]
        ]

        Retry.request(http_request_function, opts)

        assert_called_exactly(HTTPoison.get(:_, :_), 2)
      end
    end

    test "throws an error if invalid options are provided" do
      with_mock HTTPoison, [], http_poison_mock() do
        http_request_function = fn -> HTTPoison.get("http://example.com", [], recv_timeout: 60_000) end

        assert_raise ArgumentError, fn -> Retry.request(http_request_function, max_retries: 3) end
        assert_raise ArgumentError, fn -> Retry.request(http_request_function, max_attempts: "100") end
        assert_raise ArgumentError, fn -> Retry.request(http_request_function, delay_opts: %{}) end
        assert_raise ArgumentError, fn -> Retry.request(http_request_function, delay_opts: [header: "something"]) end

        assert_raise ArgumentError, fn ->
          Retry.request(http_request_function, delay_opts: [header: "something", granularity: :non_supported])
        end
      end
    end
  end

  def http_poison_mock(status_code \\ 500) do
    [
      get: fn _url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: status_code,
           request: %HTTPoison.Request{url: "http://example.com", method: "get"}
         }}
      end,
      post: fn _url, _params, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end
    ]
  end
end
