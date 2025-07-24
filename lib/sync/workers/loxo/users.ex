defmodule Sync.Workers.Loxo.Users do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :loxo, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Loxo

  require Logger

  @initial_limit 100
  @initial_offset 0

  #########################
  #   Initial syncing     #
  #########################

  def process(%Job{args: %{"type" => "pull_users_from_loxo", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling users from Loxo for Loxo integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Loxo.Reader.pull_loxo_users(integration)

    :ok
  end

  def process(%Job{args: %{"type" => "pull_users_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling users from Whippy for Loxo integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_whippy_users(integration, @initial_limit, @initial_offset)

    :ok
  end
end
