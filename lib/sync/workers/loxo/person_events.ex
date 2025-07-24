defmodule Sync.Workers.Loxo.PersonEvents do
  @moduledoc """
  This module handles Loxo integration jobs for syncing person events.

  It uses the Oban Pro Workflow to process two main types of jobs:
  1. Pulling daily messages from Whippy.
  2. Pushing daily person activities to Loxo.
  """
  use Oban.Pro.Workers.Workflow, queue: :loxo, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 10
  @initial_offset 0

  @doc """
  Processes jobs for pulling daily messages from Whippy.

  Expects the job args to include:
  - `type`: "daily_pull_messages_from_whippy"
  - `integration_id`: ID of the integration to be used
  - `day`: The day for which messages are to be pulled in ISO8601 format

  Retrieves the integration details and delegates the message pulling to `Workers.Whippy.Reader.pull_daily_whippy_messages/4`

  ## Parameters
  - job: An Oban job struct with the expected arguments.

  ## Examples

      iex> process(%Job{args: %{"type" => "daily_pull_messages_from_whippy", "integration_id" => "123", "day" => "2023-07-15"}})
      :ok
  """
  def process(
        %Job{args: %{"type" => "daily_pull_messages_from_whippy", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("Loxo integration #{integration_id} daily sync for #{iso_day}. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)
    Logger.info("Pulling messages from Whippy for integration #{inspect(integration)}")

    Workers.Whippy.Reader.pull_daily_whippy_messages(
      integration,
      iso_day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  # Processes jobs for pushing daily person activities to Loxo.

  # Expects the job args to include:
  # - `type`: "daily_push_person_activities_to_loxo"
  # - `integration_id`: ID of the integration to be used
  # - `day`: The day for which activities are to be pushed in ISO8601 format

  # Retrieves the integration details and delegates the activities pushing to `Workers.Loxo.Writer.bulk_push_daily_person_events_to_loxo/4`.

  # ## Parameters
  # - job: An Oban job struct with the expected arguments.

  # ## Examples

  #     iex> process(%Job{args: %{"type" => "daily_push_person_activities_to_loxo", "integration_id" => "123", "day" => "2023-07-15"}})
  #     :ok
  def process(
        %Job{
          args: %{"type" => "daily_push_person_activities_to_loxo", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info("Loxo integration #{integration_id} daily sync for #{iso_day}. Pushing messages to Loxo.")

    {:ok, day} = Date.from_iso8601(iso_day)

    integration = Integrations.get_integration!(integration_id)

    Workers.Loxo.Writer.bulk_push_daily_person_events_to_loxo(
      integration,
      day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_messages_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Loxo] Pulling messages from Whippy for integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_person_activities_to_loxo", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing person activities to Loxo for integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Workers.Loxo.Writer.bulk_push_person_events_to_loxo(
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  # Handles unknown job types.

  # Logs an error message indicating the unknown job type.

  # ## Parameters
  # - unknown_job: An Oban job struct that does not match the expected job types.

  # ## Examples

  #     iex> process(%Job{args: %{"type" => "unknown_type"}})
  #     :ok
  def process(unknown_job) do
    Logger.error("Unknown job type: #{inspect(unknown_job)}")
    :ok
  end
end
