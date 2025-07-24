defmodule Sync.Workers.Loxo.Reader do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Loxo worker to sync Loxo data into the Sync database.
  """

  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Integrations

  require Logger

  ################
  ##   People   ##
  ################

  def pull_loxo_people(integration, limit, scroll_id \\ nil) do
    {:ok, api_key} = Authentication.Loxo.get_api_key(integration)
    {:ok, agency_slug} = Authentication.Loxo.get_agency_slug(integration)
    {:ok, people, new_scroll_id} = Clients.Loxo.list_people(api_key, agency_slug, scroll_id)

    Contacts.save_external_contacts(integration, people)

    if new_scroll_id do
      pull_loxo_people(integration, limit, new_scroll_id)
    else
      :ok
    end
  end

  ###############
  ##   Users   ##
  ###############

  def pull_loxo_users(integration) do
    {:ok, api_key} = Authentication.Loxo.get_api_key(integration)
    {:ok, agency_slug} = Authentication.Loxo.get_agency_slug(integration)
    {:ok, users} = Clients.Loxo.list_users(api_key, agency_slug)

    Integrations.save_external_users(integration, users)
  end
end
