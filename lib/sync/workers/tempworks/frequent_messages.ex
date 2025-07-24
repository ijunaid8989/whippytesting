defmodule Sync.Workers.Tempworks.FrequentMessages do
  @moduledoc """
  Handles syncing of messages between Whippy and TempWorks.

  This module is responsible for:
  1. Pulling messages from Whippy for a specific day
  2. Pushing those messages to TempWorks

  It supports both initial syncing of all messages and daily incremental syncs.
  """

  use Oban.Pro.Workers.Workflow,
    queue: :tempworks_frequent,
    max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  # Constants for pagination when pulling messages from Whippy
  @initial_pull_limit 200
  @initial_pull_offset 0

  # Constants for pagination when pushing messages to TempWorks
  @initial_push_limit 1000
  @initial_push_offset 0

  # Set job timeout to 2 hours to handle large message volumes
  @job_execution_time_in_minutes 60 * 2

  @doc """
  Sets the timeout for job execution to prevent jobs from running indefinitely.
  Returns timeout in milliseconds.
  """
  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  @doc """
  Processes the job to pull messages from Whippy for a specific day.

  Args:
  - integration_id: ID of the TempWorks integration
  - day: ISO formatted date string for which messages should be pulled

  The function:
  1. Fetches the integration details
  2. Pulls messages from Whippy for the specified day using pagination
  3. Returns :ok on successful completion

  The Other function below.

  Processes the job to push messages to TempWorks for a specific day.

  Args:
  - integration_id: ID of the TempWorks integration
  - day: ISO formatted date string for which messages should be pushed

  The function:
  1. Converts ISO date string to Date struct
  2. Fetches the integration details
  3. Pushes messages to TempWorks using pagination
  4. Returns :ok on successful completion
  """
  def process(
        %Job{
          args: %{"type" => "frequently_pull_messages_from_whippy", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Frequently sync for #{iso_day}. Pulling messages from Whippy."
    )

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_day, @initial_pull_limit, @initial_pull_offset)

    :ok
  end

  def process(
        %Job{
          args: %{"type" => "frequently_push_messages_to_tempworks", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Frequently sync for #{iso_day}. Pushing messages to Tempworks."
    )

    with {:ok, day} <- Date.from_iso8601(iso_day) do
      integration = Integrations.get_integration!(integration_id)

      Workers.Tempworks.Writer.bulk_push_frequently_messages_to_tempworks(
        integration,
        day,
        @initial_push_limit,
        @initial_push_offset
      )

      :ok
    end
  end
end
