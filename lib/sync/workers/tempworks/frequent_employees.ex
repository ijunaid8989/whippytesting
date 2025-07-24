defmodule Sync.Workers.Tempworks.FrequentEmployees do
  @moduledoc """
  Handles syncing of contacts (employees) to and from TempWorks.
  """

  use Oban.Pro.Workers.Workflow, queue: :tempworks_frequent, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  # 45 mins
  @job_execution_time_in_minutes 45

  #######################
  #   Daily syncing     #
  #######################

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(%Job{args: %{"type" => "sync_todays_employees", "integration_id" => integration_id}} = _job) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] syncing frequent employee. Pulling frequent employees from Tempworks."
    )

    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Reader.process_todays_employees(integration)

    :ok
  end
end
