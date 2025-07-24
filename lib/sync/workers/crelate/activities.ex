defmodule Sync.Workers.Crelate.Activities do
  @moduledoc """
  Handles syncing of messages from whippy to crelate.

  Works both for initial syncing, daily syncing and frequently syncing of all messages.
  """

  use Oban.Pro.Workers.Workflow, queue: :crelate, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_pull_limit 200
  @initial_pull_offset 0

  @initial_push_limit 1000
  @initial_push_offset 0
  # 5 hours
  @job_execution_time_in_minutes 60 * 7

  #######################
  #   Daily syncing     #
  #######################

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_pull_messages_from_whippy"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_day, @initial_pull_limit, @initial_pull_offset)

    :ok
  end

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_push_messages_to_crelate"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. pushing messages to Crelate.")

    integration = Integrations.get_integration!(integration_id)

    {:ok, day} = Date.from_iso8601(iso_day)

    Workers.Crelate.Writer.bulk_push_daily_messages_to_crelate(
      integration,
      day,
      @initial_pull_limit,
      @initial_pull_offset
    )

    :ok
  end

  def process(
        %Job{
          args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "frequently_push_messages_to_crelate"}
        } = _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Frequently sync for #{iso_day}. Pushing messages to Crelate.")

    {:ok, day} = Date.from_iso8601(iso_day)

    integration = Integrations.get_integration!(integration_id)

    Workers.Crelate.Writer.bulk_push_frequently_messages_to_crelate(
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
    Logger.info("Crelate integration #{integration_id} full sync. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_pull_limit, @initial_pull_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_messages_to_crelate", "integration_id" => integration_id}} = _job) do
    Logger.info("Crelate integration #{integration_id} full sync. Pushing messages to Crelate.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Crelate.Writer.bulk_push_messages_to_crelate(integration, @initial_push_limit, @initial_push_offset)

    :ok
  end
end
