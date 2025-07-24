defmodule Sync.Workers.Aqore.Comments do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Aqore

  require Logger

  @initial_limit 800
  @initial_offset 0

  def process(%Job{args: %{"type" => "push_messages_to_aqore", "integration_id" => integration_id} = _params}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]
    Logger.info("Pushing messages to Aqore for integration", metadata)

    Aqore.Writer.bulk_push_comments_to_aqore(integration, @initial_limit, @initial_offset)
    :ok
  end

  def process(%Job{args: %{"type" => "pull_messages_from_whippy", "integration_id" => integration_id} = _params}) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client]
    Logger.info("Pulling messages from Whippy for integration", metadata)

    Workers.Whippy.Reader.bulk_pull_whippy_messages(integration, @initial_limit, @initial_offset)
    :ok
  end

  def process(
        %Job{
          args: %{"type" => "daily_pull_messages_from_whippy", "integration_id" => integration_id, "sync_date" => iso_day}
        } = _job
      ) do
    integration = Integrations.get_integration!(integration_id)
    metadata = [integration_id: integration_id, integration_client: integration.client, date: iso_day]
    Logger.info("Daily pulling messages from Whippy for integration", metadata)

    Workers.Whippy.Reader.pull_daily_whippy_messages(
      integration,
      iso_day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  def process(%Job{
        args: %{"type" => "daily_push_comments_to_aqore", "integration_id" => integration_id, "sync_date" => iso_day}
      }) do
    {:ok, day} = Date.from_iso8601(iso_day)
    integration = Integrations.get_integration!(integration_id)

    metadata = [integration_id: integration_id, integration_client: integration.client, date: iso_day]
    Logger.info("Daily push comments", metadata)

    Workers.Aqore.Writer.bulk_push_daily_comments_to_aqore(
      integration,
      day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  ################
  ## Message Sync ##
  ################
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
    Logger.info("Frequently pull messages from Whippy", metadata)

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

  ################
  ## Message Sync End##
  ################
end
