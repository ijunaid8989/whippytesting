defmodule Sync.Workers.Crelate.Entities do
  @moduledoc """
  Handles syncing of contacts (candidaes/employees/contacts) to and from Crelate.

  Works both for initial syncing of all contacts,
  and daily syncing of newly created contacts.
  """

  use Oban.Pro.Workers.Workflow, queue: :crelate, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0
  # 5 hours
  @job_execution_time_in_minutes 60 * 7
  @initial_limit 100

  #######################
  #   Daily syncing     #
  #######################

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_pull_contacts_from_crelate"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling contacts from Crelate.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Crelate.Reader.pull_daily_contacts(
      integration,
      iso_day,
      @initial_limit,
      integration.settings["contacts_offset"] || @initial_offset
    )

    :ok
  end

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_pull_contacts_from_whippy"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling contacts from Whippy.")

    integration = Integrations.get_integration!(integration_id)
    Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)
    :ok
  end

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_push_contacts_to_crelate"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. Pushing contacts to Crelate.")

    {:ok, day} = Date.from_iso8601(iso_day)

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Crelate.Writer.push_contacts_to_crelate(day, @initial_limit)

    :ok
  end

  def process(
        %Job{args: %{"day" => iso_day, "integration_id" => integration_id, "type" => "daily_push_contacts_to_whippy"}} =
          _job
      ) do
    Logger.info("[Crelate] [Integration #{integration_id}] Daily sync for #{iso_day}. Pushing contacts to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    {:ok, day} = Date.from_iso8601(iso_day)

    Workers.Whippy.Writer.daily_push_contacts_to_whippy(
      :crelate,
      integration,
      day,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  #########################
  #     Full syncing      #
  #########################

  def process(%Job{args: %{"type" => "pull_contacts_from_crelate", "integration_id" => integration_id}} = _job) do
    Logger.info("[Crelate] [Integration #{integration_id}] Pulling contacts from Crelate.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Crelate.Reader.pull_contacts(
      integration,
      @initial_limit,
      integration.settings["contacts_offset"] || @initial_offset
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Crelate] [Integration #{integration_id}] Pulling contacts from Whippy.")

    integration = Integrations.get_integration!(integration_id)
    Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_crelate", "integration_id" => integration_id}} = _job) do
    Logger.info("[Crelate] [Integration #{integration_id}] Pushing contacts to Crelate.")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Crelate.Writer.push_contacts_to_crelate(@initial_limit)

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Crelate] [Integration #{integration_id}] Pushing contacts to Whippy for Crelate.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :crelate,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end
end
