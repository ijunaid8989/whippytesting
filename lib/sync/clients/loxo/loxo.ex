defmodule Sync.Clients.Loxo do
  @moduledoc """
  Loxo API client.
  """

  alias Sync.Clients.Loxo.Resources.ActivityTypes
  alias Sync.Clients.Loxo.Resources.People
  alias Sync.Clients.Loxo.Resources.PersonEvents
  alias Sync.Clients.Loxo.Resources.Users

  # People
  defdelegate list_people(api_key, agency_slug, scroll_id \\ nil), to: People
  defdelegate create_person(api_key, agency_slug, body), to: People

  # Person Activity
  defdelegate create_person_event(api_key, agency_slug, body), to: PersonEvents

  # Activty Types
  defdelegate list_activity_types(api_key, agency_slug), to: ActivityTypes

  # Users
  defdelegate list_users(api_key, agency_slug), to: Users
end
