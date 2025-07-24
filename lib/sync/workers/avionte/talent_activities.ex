defmodule Sync.Workers.Avionte.TalentActivities do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte
  alias Sync.Workers.Avionte.Utils

  require Logger

  @initial_limit 10
  @initial_offset 0

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_messages_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling messages from Whippy for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_limit, @initial_offset)

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)
          Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_limit, @initial_offset)
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_talent_activities_to_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing talent activities to Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Writer.bulk_push_talent_activities_to_avionte(integration, @initial_limit, @initial_offset)

    :ok
  end

  ###########################
  #      Daily syncing      #
  ###########################

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
