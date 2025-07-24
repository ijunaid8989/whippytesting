defmodule Sync.Workers.Tempworks.Messages do
  @moduledoc """
  Handles syncing of messages to TempWorks.

  Works both for initial syncing of all messages,
  and daily syncing of newly created messages.
  """

  use Oban.Pro.Workers.Workflow,
    queue: :tempworks,
    max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_pull_limit 200
  @initial_pull_offset 0

  @initial_push_limit 1000
  @initial_push_offset 0
  # 12 hours
  @job_execution_time_in_minutes 60 * 12

  #######################
  #   Daily syncing     #
  #######################

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"type" => "daily_pull_messages_from_whippy", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    # Workers.Whippy.Reader.bulk_pull_daily_whippy_messages(integration, iso_day, @initial_pull_limit, @initial_pull_offset)
    Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_day, @initial_pull_limit, @initial_pull_offset)

    :ok
  end

  def process(
        %Job{args: %{"type" => "daily_push_messages_to_tempworks", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pushing messages to Tempworks.")

    {:ok, day} = Date.from_iso8601(iso_day)
    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Writer.bulk_push_daily_messages_to_tempworks(
      integration,
      day,
      @initial_push_limit,
      @initial_push_offset
    )

    :ok
  end

  #######################
  #    Message syncing     #
  #######################

  def process(
        %Job{
          args: %{"type" => "frequently_pull_messages_from_whippy", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Frequently sync for #{iso_day}. Pulling messages from Whippy."
    )

    integration = Integrations.get_integration!(integration_id)

    # Workers.Whippy.Reader.bulk_pull_daily_whippy_messages(integration, iso_day, @initial_pull_limit, @initial_pull_offset)
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

    {:ok, day} = Date.from_iso8601(iso_day)
    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Writer.bulk_push_frequently_messages_to_tempworks(
      integration,
      day,
      @initial_push_limit,
      @initial_push_offset
    )

    :ok
  end

  #######################
  #    Full syncing     #
  #######################

  def process(%Job{args: %{"type" => "pull_messages_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("TempWorks integration #{integration_id} full sync. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_pull_limit, @initial_pull_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_messages_to_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("TempWorks integration #{integration_id} full sync. Pushing messages to Tempworks.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Writer.bulk_push_messages_to_tempworks(integration, @initial_push_limit, @initial_push_offset)

    :ok
  end
end
