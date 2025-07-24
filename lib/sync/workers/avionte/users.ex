defmodule Sync.Workers.Avionte.Users do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte
  alias Sync.Workers.Avionte.Utils

  require Logger

  @initial_limit 100
  @initial_offset 0

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_users_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling users from Avionte for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Avionte.Reader.pull_avionte_users(integration)

    :ok
  end

  def process(%Job{args: %{"type" => "pull_users_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling users from Whippy for Avionte integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Reader.pull_whippy_users(integration, @initial_limit, @initial_offset)

      branches_mapping ->
        Enum.each(branches_mapping, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)
          Workers.Whippy.Reader.pull_whippy_users(integration, @initial_limit, @initial_offset)
        end)
    end

    :ok
  end
end
