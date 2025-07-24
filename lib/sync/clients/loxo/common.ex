defmodule Sync.Clients.Loxo.Common do
  @moduledoc """
  Common functions for the Loxo API.
  """

  require Logger

  @valid_entities [:person, :person_event]

  @doc """
  Gets the headers for the Loxo API.

  ## Arguments
    - `api_key` - The Loxo API key.

  ## Returns
    - `list()` - The list of headers.
  """
  @spec get_headers(binary()) :: list()
  def get_headers(api_key) when is_binary(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  @spec get_headers(any()) :: list()
  def get_headers(invalid_api_key) do
    Logger.error("Invalid API key provided to Loxo get_headers: #{inspect(invalid_api_key)}")
    []
  end

  @doc """
  Gets the base URL for the Loxo API.

  ## Returns
    - `binary()` - The base URL.
  """
  @spec get_base_url() :: binary()
  def get_base_url do
    Application.get_env(:sync, :loxo_api)
  end

  @doc """
  Converts a map to a list of key-value pairs with the key prefixed with "person[" and suffixed with "]".
  This is used to build the payload for the Loxo API.

  ## Parameters
    - `body` - A map of key-value pairs to convert to the Loxo API payload.
    - `options` - A map of options to use for the payload.
      - `email_type_id` - Represents the email type in Loxo for the organisation.
      - `phone_type_id` - Represents the phone type in Loxo for the organisation.
    - `entity` - The entity to use for the payload.

  ## Examples
     iex> Clients.Loxo.Common.build_payload(%{"name" => "Test"}, %{}, :person)
     [{"person[name]", "Test"}]

     iex> Clients.Loxo.Common.build_payload(%{"name" => "Test", "email" => "test@test.com"}, %{}, :person)
     [{"person[name]", "Test"}, {"person[email]", "test@test.com"}]

     iex> Clients.Loxo.Common.build_payload(%{"name" => "Test", "email" => "test@test.com"}, %{"email_type_id" => "144403", "phone_type_id" => "144404"}, :person)
     [{"person[name]", "Test"}, {"person[email]", "test@test.com"}, {"person[emails][0][value]", "test@test.com"}, {"person[emails][0][email_type_id]", "144403"}, {"person[emails][0][position]", 0}]
  """
  def build_payload(body, _options, entity) when is_map(body) and entity in @valid_entities do
    # email_type_id = options[:email_type_id]
    # phone_type_id = options[:phone_type_id]

    body
    |> Enum.filter(fn {_key, value} -> value != nil end)
    |> Enum.flat_map(fn {key, value} ->
      case key do
        # Note: removing email and phone mapping temporarily due to issue with Loxo API with email_type_id
        # Comment here: https://linear.app/whippy/issue/WHI-3938/loxo-integration-overview#comment-2f2e89b1
        # "email" ->
        #   [
        #     {"person[emails][0][value]", value},
        #     {"person[emails][0][email_type_id]", email_type_id},
        #     {"person[emails][0][position]", 0}
        #   ]

        # "phone" ->
        #   [
        #     {"person[phones][0][value]", value},
        #     {"person[phones][0][phone_type_id]", phone_type_id},
        #     {"person[phones][0][position]", 0}
        #   ]

        _ ->
          [{"#{entity}[#{key}]", value}]
      end
    end)
  end

  @spec build_payload(any(), any(), any()) :: list()
  def build_payload(invalid_payload, _invalid_entities, _entity) do
    Logger.error("Invalid payload passed to Loxo build_payload: #{inspect(invalid_payload)}")
    []
  end

  @doc """
  Handles the response from the Loxo API.

  ## Arguments
    - `response` - The HTTPoison response tuple that is returned after a request to the Loxo API.

  ## Returns
    - `{:ok, term()}` - The decoded response body.
    - `{:error, term()}` - The error tuple.
  """
  @spec handle_response({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, term()} | {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}}) when code in 200..201 do
    response = Jason.decode!(body)

    {:ok, response}
  end

  @spec handle_response({:ok, HTTPoison.Response.t()}) :: {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body}}) do
    {:error, body}
  end

  @spec handle_response({:error, HTTPoison.Error.t()}) :: {:error, term()}
  def handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
  end

  @spec handle_response(any()) :: {:error, term()}
  def handle_response(error) do
    {:error, error}
  end

  @spec handle_response({:ok, HTTPoison.Response.t()}, (map() -> {:ok, any()})) ::
          {:ok, term()} | {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}}, success_callback)
      when code in 200..201 do
    body
    |> Jason.decode!()
    |> success_callback.()
  end

  @spec handle_response({:ok, HTTPoison.Response.t()}, (map() -> {:ok, any()})) ::
          {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body}}, _success_callback) do
    {:error, body}
  end

  @spec handle_response({:ok, HTTPoison.Response.t()}, (map() -> {:ok, any()})) ::
          {:error, term()}
  def handle_response({:ok, %HTTPoison.Response{status_code: status, body: body}} = error, _success_callback) do
    Logger.error("[Loxo] HTTP error, status code: #{status}, body: #{inspect(body)}")

    {:error, error}
  end

  @spec handle_response({:error, HTTPoison.Error.t()}, (map() -> {:ok, any()})) ::
          {:error, term()}
  def handle_response({:error, %HTTPoison.Error{reason: reason}}, _success_callback) do
    {:error, reason}
  end
end
