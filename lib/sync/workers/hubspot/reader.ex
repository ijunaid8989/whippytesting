defmodule Sync.Workers.Hubspot.Reader do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Hubspot worker to sync Hubspot data into the Sync database.
  """

  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  require Logger

  @spec pull_owners(Integration.t(), binary()) :: :ok
  def pull_owners(integration, cursor \\ "") do
    case Clients.Hubspot.pull_owners(Clients.Hubspot.get_client(integration), cursor) do
      {:ok, [] = _owners} ->
        :ok

      {:ok, [_ | _] = owners} ->
        Integrations.save_external_users(integration, owners)
        :ok

      {:ok, [_ | _] = owners, cursor} when cursor != "" ->
        Integrations.save_external_users(integration, owners)
        pull_owners(integration, cursor)
        :ok
    end
  end

  @spec pull_contacts(Integration.t(), binary()) :: :ok
  def pull_contacts(integration, cursor \\ "") do
    case Clients.Hubspot.pull_contacts(Clients.Hubspot.get_client(integration), cursor) do
      {:ok, [] = _contacts} ->
        :ok

      {:ok, [_ | _] = contacts} ->
        Contacts.save_external_contacts(integration, contacts)
        last_id = List.last(contacts).external_contact_id

        if last_id != cursor do
          update_cursor(integration, last_id)
          :ok
        end

      {:ok, contacts, cursor} ->
        Contacts.save_external_contacts(integration, contacts)
        update_cursor(integration, cursor)
        pull_contacts(integration, cursor)
        :ok
    end
  end

  defp update_cursor(integration, cursor) do
    settings = Map.put(integration.settings, "contact_cursor", cursor)

    Integrations.update_integration(integration, %{
      settings: settings
    })
  end
end
