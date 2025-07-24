defmodule Sync.Workers.Hubspot.Webhooks do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :hubspot, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers.Whippy

  require Logger

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "subscribe_to_webhooks"}}) do
    integration = Integrations.get_integration!(integration_id)

    if integration.settings["subscribe_to_webhooks"] do
      Logger.info("Subscribing to Hubspot webhooks for integration #{integration_id}")

      {:ok, application} =
        Whippy.Writer.create_developer_application(
          integration,
          integration.integration,
          "Hubspot Integration Webhooks"
        )

      url = "#{get_base_url()}/webhooks/v1/hubspot/whippy?integration_id=#{integration_id}"

      {:ok, _} =
        Whippy.Writer.create_developer_endpoint(
          integration,
          application["data"]["id"],
          ["message.updated", "call.analyzed"],
          url
        )

      Integrations.update_integration(integration, %{
        "settings" => Map.put(integration.settings, "subscribe_to_webhooks", false)
      })
    end

    :ok
  end

  defp get_base_url do
    System.get_env("BASE_URL", "http://localhost:#{System.get_env("PORT", "4001")}")
  end
end
