defmodule Sync.Workers.Avionte.Talents do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  import Ecto.Query

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte
  alias Sync.Workers.Avionte.Utils

  require Logger

  @initial_avionte_pull_limit 250
  @initial_limit 100
  @initial_offset 0

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_talents_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling talents from Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Reader.pull_avionte_talents(integration, @initial_avionte_pull_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling contacts from Whippy for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)

      branches_mapping ->
        Enum.each(branches_mapping, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)
          Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing contacts to Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Avionte.Writer.push_contacts_to_avionte(integration, @initial_limit)

      mappings ->
        mappings
        |> Enum.filter(fn mapping -> Map.get(mapping, "should_sync_to_avionte", false) == true end)
        |> Enum.each(fn mapping ->
          integration = Utils.modify_integration(integration, mapping)

          Avionte.Writer.push_contacts_to_avionte(integration, @initial_limit)
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_talents_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing talents to Whippy for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Writer.push_contacts_to_whippy(:avionte, integration, @initial_limit, @initial_offset)

      branches_mapping ->
        Enum.each(branches_mapping, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)

          Workers.Whippy.Writer.push_contacts_to_whippy(
            :avionte,
            integration,
            @initial_limit,
            @initial_offset,
            dynamic([c], fragment("?->>'officeName' = ?", c.external_contact, ^mapping["office_name"]))
          )
        end)
    end

    :ok
  end

  # Note: this is not currently part of any workflow, but it can be used if we want to enforce certain
  # fields to be present when creating a talent in Avionte
  def process(%Job{args: %{"type" => "pull_talent_requirement_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling talent requirements from Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Reader.pull_avionte_talent_requirements(integration)

    :ok
  end
end
