defmodule Sync.Clients.Loxo.Resources.PersonEvents do
  @moduledoc false
  import Sync.Clients.Loxo.Common
  import Sync.Clients.Loxo.Parser

  require Logger

  @doc """
  Creates a person event.

  ## Arguments
  - `body` - The body of the request.
  - `api_key` - The Loxo API key.
  - `agency_slug` - The agency slug.
  """
  # @spec create_person_event(body, api_key, agency_slug) :: {:ok, map()} | {:error, map()}
  def create_person_event(api_key, agency_slug, body) do
    url = "#{get_base_url()}/#{agency_slug}/person_events"
    headers = get_headers(api_key)
    payload = build_payload(body, %{}, :person_event)
    options = [headers: headers]

    response =
      url
      |> HTTPoison.post({:form, payload}, headers, options)
      |> handle_response()

    case response do
      {:ok, %{"person_event" => person_event}} ->
        parse(person_event, :person_event)

      {:error, error} ->
        {:error, error}
    end
  end
end
