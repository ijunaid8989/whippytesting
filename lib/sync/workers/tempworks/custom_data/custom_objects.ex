defmodule Sync.Workers.Tempworks.CustomData.CustomObjects do
  @moduledoc """
  Handles fetching whippy custom objects and storing them in the sync app.
  Eventually it will hold the logic for fetching custom objects from Tempworks.
  """

  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias Sync.Clients.Tempworks.Model.Customers
  alias Sync.Clients.Tempworks.Model.EmployeeAssignment
  alias Sync.Clients.Tempworks.Model.EmployeeDetail
  alias Sync.Clients.Tempworks.Model.EmployeeStatus
  alias Sync.Clients.Tempworks.Model.TempworkContactDetail
  alias Sync.Clients.Tempworks.Model.TempworksJobOrders
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Tempworks.Parser
  @initial_limit 100
  @initial_offset 0
  # 5 hours
  @job_execution_time_in_minutes 60 * 5

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(%Job{args: %{"type" => "pull_custom_objects_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pulling custom_objects from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Reader.pull_custom_objects(
      integration,
      @initial_limit,
      @initial_offset
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_custom_objects_from_tempworks", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] pulling custom_objects from TempWorks.")

    integration = Integrations.get_integration!(integration_id)

    Workers.CustomData.CustomObjects.pull_custom_objects(
      @parser_module,
      integration,
      external_entity_type_to_model_mapper()
    )

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_objects_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pushing custom_objects with properties to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_custom_objects(
      integration,
      @initial_limit
    )

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_object_records_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Pushing custom_object_records to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Whippy.Writer.push_custom_object_records(
      integration,
      @initial_limit
    )

    :ok
  end

  defp external_entity_type_to_model_mapper do
    %{
      "employee" => [
        %EmployeeDetail{},
        %EmployeeStatus{},
        fn integration -> Workers.Tempworks.Reader.get_employee_custom_data(integration) end
      ],
      "assignment" => [
        %EmployeeAssignment{},
        fn integration -> Workers.Tempworks.Reader.get_assignment_custom_data(integration) end
      ],
      "tempworks_contacts" => [
        %TempworkContactDetail{},
        fn integration -> Workers.Tempworks.Reader.get_contact_custom_data(integration) end
      ],
      "job_orders" => [
        %TempworksJobOrders{},
        fn integration -> Workers.Tempworks.Reader.get_jobs_custom_data(integration) end
      ],
      "customers" => [
        %Customers{},
        fn integration -> Workers.Tempworks.Reader.get_customer_custom_data(integration) end
      ]
    }
  end
end
