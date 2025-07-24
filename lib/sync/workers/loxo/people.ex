defmodule Sync.Workers.Loxo.People do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :loxo, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Loxo

  require Logger

  @initial_limit 100
  @initial_offset 0
  @initial_scroll_id nil

  def process(%Job{args: %{"type" => "pull_people_from_loxo", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling people from Loxo for Loxo integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)
    Loxo.Reader.pull_loxo_people(integration, @initial_limit, @initial_scroll_id)
    :ok
  end

  def process(%Job{args: %{"type" => "pull_contacts_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pulling contacts from Whippy for Loxo integration #{integration_id}")

    integration = Integrations.get_integration!(integration_id)
    Workers.Whippy.Reader.pull_whippy_contacts(integration, @initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_contacts_to_loxo", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing contacts to Loxo for Loxo integration #{integration_id}")
    integration = Integrations.get_integration!(integration_id)
    Loxo.Writer.push_contacts_to_loxo(integration, @initial_limit)
    :ok
  end

  def process(%Job{args: %{"type" => "push_people_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("Pushing people to Whippy for Loxo integration #{integration_id}")
    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_contacts_to_whippy(
      :loxo,
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end
end
