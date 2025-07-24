defmodule Sync.Workers.Tempworks.CustomData.Customers do
  @moduledoc """
  Handles fetching job orders and converting them to custom object records.
  """

  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Tempworks.Parser
  @initial_limit 500
  @initial_offset 0
  # 18 hours
  @job_execution_time_in_minutes 60 * 18

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"type" => "process_customers_as_custom_object_records", "integration_id" => integration_id}} = _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Fetching customers and converting them to custom object records."
    )

    integration = Integrations.get_integration!(integration_id)

    case Contacts.list_custom_objects_by_external_entity_type(integration, "customers") do
      [] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] No custom object found for customers.")

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.Tempworks.Reader.pull_customers(
          @parser_module,
          integration,
          custom_object,
          @initial_limit,
          @initial_offset
        )

      [_custom_object] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] customers custom_object not synced to whippy.")

      _ ->
        Logger.error("[TempWorks] [Integration #{integration_id}] Multiple custom objects found for customers.")
    end

    :ok
  end
end
