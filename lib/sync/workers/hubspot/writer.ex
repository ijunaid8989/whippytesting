defmodule Sync.Workers.Hubspot.Writer do
  @moduledoc false
  alias Sync.Activities
  alias Sync.Clients
  alias Sync.Contacts

  require Logger

  @limit 100

  def push_contacts(integration, contacts \\ []) do
    contacts =
      if contacts == [] do
        Contacts.list_integration_contacts_missing_from_external_integration(integration, @limit)
      else
        contacts
      end

    if length(contacts) > 0 do
      external_contacts =
        integration
        |> Clients.Hubspot.get_client()
        |> Clients.Hubspot.push_contacts(contacts)

      Contacts.save_external_contacts(integration, external_contacts)

      push_contacts(integration)
    else
      :ok
    end
  end

  def push_activities(integration) do
    activities =
      integration
      |> Activities.list_whippy_messages_missing_from_external_integration(@limit)
      |> Enum.reject(fn activity -> is_nil(activity.external_contact_id) end)

    if length(activities) > 0 do
      integration
      |> Clients.Hubspot.get_client()
      |> Clients.Hubspot.push_activities(activities)

      # create fake external ids as there is no way to match with Hubspot activity id
      # when you do bulk create. All we need to do is mark the message as synced.
      Enum.each(activities, fn activity ->
        Activities.update_activity_synced_in_external_integration(activity, "synced", %{})
      end)

      push_activities(integration)
    else
      :ok
    end
  end
end
