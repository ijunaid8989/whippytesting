defmodule Sync.Workers.Avionte.Branches do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers.Avionte

  require Logger

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_branches_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] Daily sync. Pulling branches from Avionte.")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Reader.pull_branches(integration)

    :ok
  end
end
