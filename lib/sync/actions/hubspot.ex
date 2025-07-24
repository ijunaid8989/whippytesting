defmodule Sync.Actions.Hubspot do
  @moduledoc """
  Process hubspot custom actions

  More info https://developers.hubspot.com/docs/api/automation/custom-workflow-actions
  """
  alias Sync.Clients.Hubspot
  alias Sync.Clients.Whippy
  alias Sync.Contacts
  alias Sync.Workers.Hubspot.Writer, as: HubspotWriter
  alias Sync.Workers.Whippy.Reader, as: WhippyReader

  @doc """
  send_sms action from Hubspot
  payload example

  %{
    "callbackId" => "ap-145484877-403081688006-1-0",
    "context" => %{"source" => "WORKFLOWS", "workflowId" => 1567555043},
    "fields" => %{"messageBody" => "Hi Test User9,\n\nThis is a test SMS"},
    "inputFields" => %{"messageBody" => "Hi Test User9,\n\nThis is a test SMS"},
    "object" => %{"objectId" => 44933811680, "objectType" => "CONTACT"},
    "origin" => %{
      "actionDefinitionId" => 77899621,
      "actionDefinitionVersion" => 1,
      "actionExecutionIndexIdentifier" => %{
        "actionExecutionIndex" => 0,
        "enrollmentId" => 403081688006
      },
      "extensionDefinitionId" => 77899621,
      "extensionDefinitionVersionId" => 1,
      "portalId" => 145484877
    }
  }
  """
  def send_sms(payload) do
    %{authentication: authentication} =
      integration = get_action_integration(payload["origin"]["portalId"])

    {:ok, channel} =
      Whippy.get_channel(authentication["whippy_api_key"], payload["inputFields"]["channelId"])

    response =
      integration
      |> Hubspot.get_client()
      |> Hubspot.search_contacts_by_id([payload["object"]["objectId"]])

    case response do
      {:ok, [contact]} ->
        case Whippy.send_message(
               authentication["whippy_api_key"],
               contact.phone,
               channel.phone,
               payload["inputFields"]["messageBody"]
             ) do
          {:ok, %{"delivery_status" => "failed"}} -> :error
          _ -> :ok
        end

      _ ->
        :error
    end
  end

  @spec push_activities(String.t(), list(map())) :: [map()]
  def push_activities(integration_id, activities) do
    integration = Sync.Integrations.get_integration!(integration_id)

    activities =
      if is_nil(integration.settings["channels"]) do
        activities
      else
        Enum.filter(activities, fn activity ->
          Enum.member?(integration.settings["channels"], activity.whippy_activity["channel_id"])
        end)
      end

    contacts = get_activities_contacts_map(integration_id, activities)

    activities_without_contacts =
      Enum.filter(activities, fn activity -> !Map.has_key?(contacts, activity.whippy_activity["contact_id"]) end)

    contacts =
      if integration.settings["push_contacts_to_hubspot"] and !Enum.empty?(activities_without_contacts) do
        contact_ids =
          Enum.map(activities_without_contacts, fn activity -> activity.whippy_activity["contact_id"] end)

        sync_contacts_with_whippy(integration, contact_ids)
        sync_contacts_to_hubspot(integration, contact_ids)
        get_activities_contacts_map(integration_id, activities)
      else
        contacts
      end

    users = get_activities_users_map(integration_id, activities)

    activities =
      activities
      |> Enum.map(fn activity ->
        contact = contacts[activity.whippy_activity["contact_id"]] || %{}
        external_contact = Map.get(contact, "external_contact", %{})
        user = users[to_string(activity.whippy_activity["user_id"])] || %{}

        activity
        |> Map.put(:external_contact_id, Map.get(contact, :external_contact_id, nil))
        |> Map.put(
          :company_id,
          Map.get(external_contact, "company_id", nil)
        )
        |> Map.put(:external_user_id, Map.get(user, :external_user_id, nil))
        |> Map.put(:external_contact_name, Map.get(contact, :name, nil))
        |> Map.put(:whippy_organization_id, integration.whippy_organization_id)
      end)
      |> Enum.reject(fn activity -> is_nil(activity.external_contact_id) end)

    result =
      integration_id
      |> Sync.Integrations.get_integration!()
      |> Hubspot.get_client()
      |> Hubspot.push_activities(activities)

    result
  end

  def get_channels(payload, type \\ "phone") do
    %{authentication: authentication} =
      get_action_integration(payload["origin"]["portalId"])

    case Whippy.list_channels(authentication["whippy_api_key"]) do
      {:ok, %{channels: channels}} ->
        Enum.filter(channels, fn channel -> channel.type == type end)

      _ ->
        []
    end
  end

  defp get_action_integration(portal_id) do
    Sync.Integrations.get_integration_by_external_organization_id!(to_string(portal_id), :hubspot)
  end

  defp get_activities_contacts_map(integration_id, activities) do
    integration_id
    |> Sync.Contacts.list_integration_contacts_by_whippy_contact_ids(
      Enum.map(activities, fn activity -> to_string(activity.whippy_activity["contact_id"]) end)
    )
    |> Map.new(fn contact ->
      {contact.whippy_contact_id, contact}
    end)
  end

  defp get_activities_users_map(integration_id, activities) do
    integration_id
    |> Sync.Integrations.get_users_by_whippy_ids(
      Enum.map(activities, fn activity -> to_string(activity.whippy_activity["user_id"]) end)
    )
    |> Map.new(fn user -> {user.whippy_user_id, user} end)
  end

  defp sync_contacts_with_whippy(integration, contact_ids) do
    # Note:use concurrency in the future when we handle more than one message per action
    Enum.each(contact_ids, fn contact_id ->
      case Contacts.get_contact_by_whippy_id(integration.id, contact_id) do
        nil -> WhippyReader.get_contact_by_id(integration, contact_id)
        _contact -> :ok
      end
    end)

    :ok
  end

  defp sync_contacts_to_hubspot(integration, contact_ids) do
    contacts = Sync.Contacts.list_integration_contacts_by_whippy_contact_ids(integration.id, contact_ids)
    HubspotWriter.push_contacts(integration, contacts)
    :ok
  end
end
