defmodule Sync.Workers.Avionte.AvionteContacts do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers.Avionte

  require Logger

  @initial_limit 100
  @initial_offset 0

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_contacts_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling contacts from Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Reader.pull_avionte_contacts(integration, @initial_limit, @initial_offset)

    :ok
  end
end
