defmodule SyncWeb.Admin.Integrations.ActivityTypeController do
  use SyncWeb, :controller

  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  def index(conn, %{"integration_id" => integration_id}) do
    case Integrations.get_integration(integration_id) do
      %Integration{client: client} = integration ->
        activity_types = list_activity_types(client, integration)
        contact_activity_types = list_contact_activity_types(client, integration)
        render(conn, :index, activity_types: activity_types, contact_activity_types: contact_activity_types)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{description: "Integration not found"}]})
    end
  end

  defp list_activity_types(:avionte, integration) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    {:ok, activity_types} = Clients.Avionte.list_talent_activity_types(api_key, access_token, tenant)
    activity_types
  end

  defp list_activity_types(:tempworks, integration) do
    {:ok, %Integration{authentication: %{"access_token" => access_token}}} =
      Authentication.Tempworks.get_or_regenerate_service_token(integration)

    {:ok, %{message_actions: activity_types}} = Clients.Tempworks.list_message_actions(access_token)

    activity_types
  end

  defp list_activity_types(:loxo, integration) do
    {:ok, api_key} = Authentication.Loxo.get_api_key(integration)
    {:ok, agency_slug} = Authentication.Loxo.get_agency_slug(integration)
    {:ok, activity_types} = Clients.Loxo.list_activity_types(api_key, agency_slug)

    activity_types
  end

  defp list_contact_activity_types(:avionte, integration) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    {:ok, activity_types} = Clients.Avionte.list_contact_activity_types(api_key, access_token, tenant)
    activity_types
  end

  defp list_contact_activity_types(_, _) do
    {:ok, %{message_actions: []}}
  end
end
