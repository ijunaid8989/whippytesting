defmodule Sync.Webhooks.Hubspot do
  @moduledoc """
  Process Hubspot webhook events.
  Example of events payload

  [
      %{
        "appId" => 3579920,
        "attemptNumber" => 0,
        "changeSource" => "CRM_UI",
        "eventId" => 2787498352,
        "isSensitive" => false,
        "objectId" => 40996296168,
        "objectTypeId" => "0-1",
        "occurredAt" => 1727363378559,
        "portalId" => 145484877,
        "propertyName" => "phone",
        "propertyValue" => "+12345678922",
        "sourceId" => "userId:68834538",
        "subscriptionId" => 2834281,
        "subscriptionType" => "object.propertyChange"
      },
      %{
        "appId" => 3579920,
        "attemptNumber" => 0,
        "changeFlag" => "CREATED",
        "changeSource" => "CRM_UI",
        "eventId" => 2235911016,
        "objectId" => 40996296168,
        "objectTypeId" => "0-1",
        "occurredAt" => 1727363378559,
        "portalId" => 145484877,
        "sourceId" => "userId:68834538",
        "subscriptionId" => 2834280,
        "subscriptionType" => "object.creation"
      }
    ]

    More information https://developers.hubspot.com/docs/api/webhooks
  """

  alias Sync.Clients.Hubspot, as: Client
  alias Sync.Clients.Whippy, as: WhippyClient
  alias Sync.Contacts
  alias Sync.Integrations
  alias Sync.Workers.Whippy

  require Logger

  @spec process_events([map()]) :: any()
  def process_events(events) do
    events
    |> Task.async_stream(
      fn event ->
        try do
          process_event(event, "#{event["subscriptionType"]},#{event["objectTypeId"]}")
        rescue
          error ->
            Logger.error("[Hubspot Webhook] Failed to process event #{inspect(event)}, #{inspect(error)}")
        end
      end,
      timeout: :infinity
    )
    |> Enum.to_list()
  end

  defp process_event(event, "object.creation,0-1") do
    integration = get_event_integration(event)

    integration
    |> Client.get_client()
    |> Client.search_contacts_by_id([event["objectId"]])
    |> then(fn
      {:ok, [contact]} when not is_nil(contact.phone) ->
        Contacts.save_external_contacts(integration, [contact])
        Whippy.Writer.push_contacts_to_whippy(:hubspot, integration, 100, 0)

      _ ->
        :ok
    end)

    :ok
  end

  defp process_event(event, "object.propertyChange,0-1") do
    integration = get_event_integration(event)

    integration
    |> Client.get_client()
    |> Client.search_contacts_by_id([event["objectId"]])
    |> then(fn
      {:ok, [contact]} when not is_nil(contact.phone) ->
        contact =
          Map.merge(contact, %{
            integration_id: integration.id,
            external_organization_id: integration.external_organization_id,
            external_id: contact.external_contact_id
          })

        case Contacts.upsert_external_contact(integration, contact) do
          {:ok, sync_contact} ->
            integration.authentication["whippy_api_key"]
            |> WhippyClient.create_contact(contact)
            |> Whippy.Writer.update_contact_synced_in_whippy(integration, sync_contact)

          {:error, changeset} ->
            Logger.error("[Hubspot Webhook] Failed to update external contact #{inspect(changeset)}")
        end

      _ ->
        :ok
    end)

    :ok
  end

  defp process_event(_event, _type), do: :ignored

  defp get_event_integration(event) do
    event["portalId"]
    |> to_string()
    |> Integrations.get_integration_by_external_organization_id!(:hubspot)
  end
end
