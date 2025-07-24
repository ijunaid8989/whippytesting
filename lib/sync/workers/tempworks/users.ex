defmodule Sync.Workers.Tempworks.Users do
  @moduledoc """
  Handles syncing of users to and from TempWorks.
  At the moment, this is a one-way sync from Whippy to the Sync database.
  """

  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_users_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync. Pulling users from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_whippy_users(integration, @initial_limit, @initial_offset)

    :ok
  end
end
