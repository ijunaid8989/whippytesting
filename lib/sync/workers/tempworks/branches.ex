defmodule Sync.Workers.Tempworks.Branches do
  @moduledoc """
  Handles syncing of branches from TempWorks.
  They are the equivalent of Whippy channels/locations.
  """
  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0
  # 5 hours
  @job_execution_time_in_minutes 60 * 5

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(%Job{args: %{"type" => "pull_branches_from_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync. Pulling branches from TempWorks.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Reader.pull_branches(integration, @initial_limit, @initial_offset)

    :ok
  end
end
