defmodule Sync.Clients.Loxo.Resources.People do
  @moduledoc """
  This module contains functions that interact with the Loxo API to get user data.
  """

  import Sync.Clients.Loxo.Common
  import Sync.Clients.Loxo.Parser

  require Logger

  @doc """
  Lists the people in Loxo.

  ## Arguments
  - `api_key` - The Loxo API key.
  - `agency_slug` - The agency slug.
  - `scroll_id` - The scroll ID to use for pagination.

  ## Returns
  - `{:ok, [Person.t()], scroll_id}` - The list of people and the scroll ID.
  - `{:error, term()}` - The error message.
  """
  def list_people(api_key, agency_slug, scroll_id \\ nil) do
    url = "#{get_base_url()}/#{agency_slug}/people"
    headers = get_headers(api_key)

    url =
      if scroll_id do
        "#{url}?scroll_id=#{scroll_id}"
      else
        url
      end

    response = url |> HTTPoison.get(headers) |> handle_response()

    case response do
      {:ok, %{"scroll_id" => new_scroll_id, "people" => people}} ->
        parsed_people = parse!(people, :people)
        {:ok, parsed_people, new_scroll_id}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Creates a person in Loxo.

  ## Arguments
  - `body` - The body of the request.
  - `api_key` - The Loxo API key.
  - `agency_slug` - The agency slug.
  - `opts` - The options for listing people.
    - `email_type_id` - The default email type ID to use for the person
    - `phone_type_id` - The default phone type ID to use for the person

  ## Returns
  - `{:ok, Person.t()}` - The created person.
  - `{:error, term()}` - The error message.
  """
  def create_person(body, api_key, agency_slug, opts \\ %{}) do
    url = "#{get_base_url()}/#{agency_slug}/people"
    headers = get_headers(api_key)

    payload = build_payload(body, opts, :person)

    options = [headers: headers]

    case url |> HTTPoison.post({:form, payload}, headers, options) |> handle_response() do
      {:ok, %{"person" => person_object}} ->
        parse(person_object, :person)

      {:error, error} ->
        Logger.error("Failed to create person: #{inspect(error)}")
        parse!(error, :error)
    end
  end
end
