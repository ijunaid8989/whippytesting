defmodule Sync.Workers.Avionte.FrequentTalentActivities do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte_messages, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte.Utils

  require Logger

  @initial_limit 10
  @initial_offset 0

  # 2 hours
  @job_execution_time_in_minutes 60 * 2

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"type" => "daily_pull_messages_from_whippy", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("Avionte integration #{integration_id} daily sync for #{iso_day}. Pulling messages from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_day, @initial_limit, @initial_offset)

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)
          Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_day, @initial_limit, @initial_offset)
        end)
    end

    :ok
  end

  def process(
        %Job{
          args: %{
            "type" => "daily_push_talent_activities_to_avionte",
            "integration_id" => integration_id,
            "day" => iso_day
          }
        } = _job
      ) do
    Logger.info("Avionte integration #{integration_id} daily sync for #{iso_day}. Pushing messages to Avionte.")

    {:ok, day} = Date.from_iso8601(iso_day)

    integration = Integrations.get_integration!(integration_id)

    Workers.Avionte.Writer.bulk_push_daily_talent_activities_to_avionte(integration, day, @initial_limit, @initial_offset)

    :ok
  end
end
