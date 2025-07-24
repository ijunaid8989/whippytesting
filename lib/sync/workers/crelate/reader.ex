defmodule Sync.Workers.Crelate.Reader do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Crelate worker to sync crelate data into the Sync database.
  """

  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  require Logger

  @spec pull_contacts(Integration.t(), integer(), integer()) :: :ok
  def pull_contacts(
        %Integration{authentication: %{"external_api_key" => api_key}, settings: %{"use_production_url" => url_mode}} =
          integration,
        limit,
        offset
      ) do
    case Clients.Crelate.get_contacts(api_key, limit: limit, offset: offset, url_mode: url_mode) do
      {:error, reason} ->
        Logger.error("[Crelate] [#{integration.id}] Error pulling contacts. Error: #{inspect(reason)}")

      {:ok, contacts} when length(contacts) < limit ->
        update_offset(:contacts_offset, integration, 0)
        Contacts.save_external_contacts(integration, contacts)

      {:ok, contacts} ->
        update_offset(:contacts_offset, integration, offset)
        Contacts.save_external_contacts(integration, contacts)
        pull_contacts(integration, limit, offset + limit)
    end
  end

  @spec pull_daily_contacts(Integration.t(), String.t(), integer(), integer()) :: :ok
  def pull_daily_contacts(
        %Integration{authentication: %{"external_api_key" => api_key}, settings: %{"use_production_url" => url_mode}} =
          integration,
        iso_day,
        limit,
        offset
      ) do
    case Clients.Crelate.get_modified_contacts(api_key, iso_day, limit: limit, offset: offset, url_mode: url_mode) do
      {:error, reason} ->
        Logger.error("[Crelate] [#{integration.id}] Error daily pulling contacts. Error: #{inspect(reason)}")

      {:ok, contacts} when length(contacts) < limit ->
        update_offset(:contacts_offset, integration, 0)
        Contacts.save_external_contacts(integration, contacts)

      {:ok, contacts} ->
        update_offset(:contacts_offset, integration, offset)
        Contacts.save_external_contacts(integration, contacts)
        pull_daily_contacts(integration, iso_day, limit, offset + limit)
    end
  end

  def update_offset(:contacts_offset, integration, offset) do
    integration = Integrations.get_integration!(integration.id)

    settings = Map.put(integration.settings, "contacts_offset", offset)
    Integrations.update_integration(integration, %{settings: settings})
  end
end
