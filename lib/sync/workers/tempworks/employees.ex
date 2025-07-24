defmodule Sync.Workers.Tempworks.Employees do
  @moduledoc """
  Handles syncing of contacts (employees) to and from TempWorks.

  Works both for initial syncing of all contacts,
  and daily syncing of newly created contacts.
  """

  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias Sync.Channels
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_employees_pull_limit 500
  @initial_limit 100
  @initial_offset 0
  # 18 hours
  @job_execution_time_in_minutes 60 * 18

  #######################
  #   Daily syncing     #
  #######################

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{
          args: %{"type" => "daily_pull_employees_from_tempworks", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling employees from Tempworks."
    )

    integration = Integrations.get_integration!(integration_id)

    # We cannot query for TempWorks employees by any dates, so we have to sync all of them each time.
    if integration.settings["use_advance_search"] do
      Workers.Tempworks.Reader.pull_advance_employees(
        integration,
        @initial_employees_pull_limit,
        integration.settings["advance_employee_offset"] || @initial_offset
      )
    else
      Workers.Tempworks.Reader.pull_employees(
        integration,
        @initial_employees_pull_limit,
        @initial_offset
      )
    end

    :ok
  end

  def process(
        %Job{
          args: %{"type" => "daily_pull_contacts_from_tempworks", "integration_id" => integration_id, "day" => iso_day}
        } = _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling contacts from Tempworks.")

    integration = Integrations.get_integration!(integration_id)

    # We cannot query for TempWorks employees by any dates, so we have to sync all of them each time.

    Workers.Tempworks.Reader.pull_contacts(
      integration,
      @initial_employees_pull_limit,
      @initial_offset
    )

    :ok
  end

  def process(
        %Job{args: %{"type" => "daily_pull_contacts_from_whippy", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pulling contacts from Whippy.")

    # TODO: Rework to query only for daily contacts.

    integration_id
    |> Integrations.get_integration!()
    # |> Workers.Whippy.Reader.pull_whippy_contacts(iso_day, @initial_limit, @initial_offset)
    |> Workers.Whippy.Reader.pull_whippy_contacts(@initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "lookup_contacts_in_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync. Looking up whippy contacts in Tempworks.")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Tempworks.Reader.lookup_employees_in_tempworks(@initial_limit)
  end

  def process(
        %Job{args: %{"type" => "daily_push_contacts_to_tempworks", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pushing contacts to Tempworks.")

    # TODO: Rework to query only for daily contacts.
    # we could leave it query for all and catch contacts that were not synced, however

    if Channels.list_mapped_external_integration_channels(integration_id) != [] do
      integration_id
      |> Integrations.get_integration!()
      |> Workers.Tempworks.Writer.push_contacts_to_tempworks(@initial_limit)
    end

    :ok
  end

  def process(
        %Job{args: %{"type" => "daily_push_employees_to_whippy", "integration_id" => integration_id, "day" => iso_day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Daily sync for #{iso_day}. Pushing employees to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    # TODO: Rework to query only for daily contacts.
    #
    # {:ok, day} = Date.from_iso8601(iso_day)
    #
    # Workers.Whippy.Writer.push_contacts_to_whippy(
    #   :tempworks,
    #   integration,
    #   day,
    #   @initial_limit,
    #   @initial_offset
    # )

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :tempworks,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  #########################
  #     Full syncing      #
  #########################

  def process(%Job{args: %{"type" => "pull_employees_from_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pulling employees from Tempworks.")

    integration = Integrations.get_integration!(integration_id)

    if integration.settings["use_advance_search"] do
      Workers.Tempworks.Reader.pull_advance_employees(
        integration,
        @initial_employees_pull_limit,
        integration.settings["advance_employee_offset"] || @initial_offset
      )
    else
      Workers.Tempworks.Reader.pull_employees(
        integration,
        @initial_employees_pull_limit,
        @initial_offset
      )
    end

    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pulling contacts from Tempworks.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Tempworks.Reader.pull_contacts(
      integration,
      @initial_employees_pull_limit,
      @initial_offset
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pulling contacts from Whippy for Tempworks.")

    # integration = Integrations.get_integration!(integration_id)

    # Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit)

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pushing contacts to Tempworks for Tempworks.")

    # integration = Integrations.get_integration!(integration_id)

    # if Channels.list_mapped_external_integration_channels(integration_id) != [] do
    #   Workers.Tempworks.Writer.push_contacts_to_tempworks(
    #     integration,
    #     @initial_limit
    #   )
    # end

    :ok
  end

  def process(%Job{args: %{"type" => "push_employees_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pushing employees to Whippy for Tempworks.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :tempworks,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  #########################
  #     Monthly syncing      #
  #########################

  def process(%Job{args: %{"type" => "monthly_pull_birthdays_from_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Monthly sync. Looking up employees birthday in Tempworks.")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Tempworks.Reader.monthly_pull_birthdays_from_tempworks(@initial_limit)
  end

  def process(
        %Job{args: %{"type" => "monthly_push_birthdays_to_whippy", "integration_id" => integration_id, "day" => day}} =
          _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Monthly sync. Pushing birth date of employees to whippy.")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Whippy.Writer.monthly_push_birthdays_to_whippy(@initial_limit, @initial_offset, day)
  end
end
