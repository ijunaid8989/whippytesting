defmodule Sync.Workers.Tempworks.CustomData.Employees do
  @moduledoc """
  Handles fetching employee details and converting them to custom object records.
  """
  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  import Ecto.Query

  alias Sync.Contacts
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @parser_module Sync.Clients.Tempworks.Parser
  @initial_limit 100
  @initial_offset 0
  # 18 hours
  @job_execution_time_in_minutes 60 * 18

  def timeout(_job), do: :timer.minutes(@job_execution_time_in_minutes)

  def process(
        %Job{args: %{"type" => "process_employees_as_custom_object_records", "integration_id" => integration_id}} = _job
      ) do
    Logger.info("[TempWorks] [Integration #{integration_id}] Converting employees to custom object records.")

    integration = Integrations.get_integration!(integration_id)

    case Contacts.list_custom_objects_by_external_entity_type(integration, "tempworks_employees") do
      [] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] No custom object found for employee.")

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.CustomData.Converter.convert_external_contacts_to_custom_object_records(
          @parser_module,
          integration,
          custom_object,
          dynamic([c], not like(c.external_contact_id, "contact-%"))
        )

      [_custom_object] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] employee custom_object not synced to whippy.")

      _ ->
        Logger.error("[TempWorks] [Integration #{integration_id}] Multiple custom objects found for employee.")
    end

    :ok
  end

  # Only be used with Basic API
  def process(
        %Job{args: %{"type" => "process_employee_details_as_custom_object_records", "integration_id" => integration_id}} =
          _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Fetching employee details and converting them to custom object records."
    )

    integration = Integrations.get_integration!(integration_id)

    case Contacts.list_custom_objects_by_external_entity_type(integration, "employee") do
      [] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] No custom object found for employee.")

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.Tempworks.Reader.pull_employee_details(
          @parser_module,
          integration,
          custom_object,
          @initial_limit,
          integration.settings["employee_details_offset"] || @initial_offset
        )

      [_custom_object] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] employee custom_object not synced to whippy.")

      _ ->
        Logger.error("[TempWorks] [Integration #{integration_id}] Multiple custom objects found for employee.")
    end

    :ok
  end

  def process(
        %Job{args: %{"type" => "process_contact_details_as_custom_object_records", "integration_id" => integration_id}} =
          _job
      ) do
    Logger.info(
      "[TempWorks] [Integration #{integration_id}] Fetching contacts details and converting them to custom object records."
    )

    integration = Integrations.get_integration!(integration_id)

    case Contacts.list_custom_objects_by_external_entity_type(integration, "tempworks_contacts") do
      [] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] No custom object found for tempwork contact.")

      [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) ->
        Workers.Tempworks.Reader.pull_contact_details(
          @parser_module,
          integration,
          custom_object,
          @initial_limit,
          integration.settings["contact_details_offset"] || @initial_offset
        )

      [_custom_object] ->
        Logger.error("[TempWorks] [Integration #{integration_id}] tempwork contact custom_object not synced to whippy.")

      _ ->
        Logger.error("[TempWorks] [Integration #{integration_id}] Multiple custom objects found for tempwork contact.")
    end

    :ok
  end
end
