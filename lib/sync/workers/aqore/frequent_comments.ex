defmodule Sync.Workers.Aqore.FrequentComments do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore_messages, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 10
  @initial_offset 0

  # 2 hours
  @job_execution_time_in_minutes 60 * 2

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{
          args: %{
            "type" => "frequently_pull_messages_from_whippy",
            "integration_id" => integration_id,
            "sync_date" => iso_day
          }
        } = _job
      ) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client, date: iso_day]
    Logger.info("Frequently pull messages from Whippy for integration", metadata)

    Workers.Whippy.Reader.pull_daily_whippy_messages(
      integration,
      iso_day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  def process(
        %Job{
          args: %{
            "type" => "frequently_push_messages_to_aqore",
            "integration_id" => integration_id,
            "sync_date" => iso_day
          }
        } = _job
      ) do
    {:ok, day} = Date.from_iso8601(iso_day)
    integration = Integrations.get_integration!(integration_id)

    metadata = [integration_id: integration_id, integration_client: integration.client, date: iso_day]
    Logger.info("Frequently pushing comments to Aqore.", metadata)

    Workers.Aqore.Writer.bulk_push_frequently_comments_to_aqore(
      integration,
      day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end
end
