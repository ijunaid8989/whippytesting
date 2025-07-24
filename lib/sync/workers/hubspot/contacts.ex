defmodule Sync.Workers.Hubspot.Contacts do
  @moduledoc """
  Handles syncing of contacts to and from Hubspot.

  Works both for initial syncing of all contacts,
  and daily syncing of newly created contacts.
  """

  use Oban.Pro.Workers.Workflow, queue: :hubspot, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_contacts_from_hubspot", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pulling contacts from Hubspot.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Hubspot.Reader.pull_contacts(
      integration,
      Map.get(integration.settings, "contact_cursor", "")
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pulling contacts from Whippy")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Whippy.Reader.pull_whippy_contacts(@initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_hubspot", "integration_id" => integration_id}} = _job) do
    integration = Integrations.get_integration!(integration_id)

    if integration.settings["push_contacts_to_hubspot"] do
      Logger.info("[Hubspot] [Integration #{integration_id}] Pushing contacts to Hubspot.")
      Workers.Hubspot.Writer.push_contacts(integration)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_whippy", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pushing contacts to Whippy.")

    integration =
      Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :hubspot,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end
end
