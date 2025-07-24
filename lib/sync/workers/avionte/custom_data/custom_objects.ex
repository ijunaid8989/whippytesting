defmodule Sync.Workers.Avionte.CustomData.CustomObjects do
  @moduledoc """
  Handles fetching custom objects from Whippy and Avionte and storing them in the Sync app,
  as well as pushing custom objects and custom object records to Whippy.
  """

  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  import Ecto.Query

  alias Sync.Clients.Avionte.Model.AvionteContact
  alias Sync.Clients.Avionte.Model.Company
  alias Sync.Clients.Avionte.Model.Jobs
  alias Sync.Clients.Avionte.Model.Placement
  alias Sync.Clients.Avionte.Model.Talent
  alias Sync.Integrations
  alias Sync.Workers
  alias Sync.Workers.Avionte.Utils

  require Logger

  @parser_module Sync.Clients.Avionte.Parser
  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_custom_objects_from_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] Pulling custom_objects from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Reader.pull_custom_objects(
          integration,
          @initial_limit,
          @initial_offset
        )

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)
          Workers.Whippy.Reader.pull_custom_objects(integration, @initial_limit, @initial_offset)
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "pull_custom_objects_from_avionte", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] pulling custom_objects from Avionte.")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.CustomData.CustomObjects.pull_custom_objects(
          @parser_module,
          integration,
          external_entity_type_to_model_mapper()
        )

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)

          Workers.CustomData.CustomObjects.pull_custom_objects(
            @parser_module,
            integration,
            external_entity_type_to_model_mapper()
          )
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_objects_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] Pushing custom_objects with properties to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Writer.push_custom_objects(
          integration,
          @initial_limit
        )

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)

          Workers.Whippy.Writer.push_custom_objects(
            integration,
            @initial_limit,
            dynamic([c], c.whippy_organization_id == ^integration.whippy_organization_id)
          )
        end)
    end

    :ok
  end

  def process(%Job{args: %{"type" => "push_custom_object_records_to_whippy", "integration_id" => integration_id}} = _job) do
    Logger.info("[Avionte] [Integration #{integration_id}] Pushing custom_object_records to Whippy.")

    integration = Integrations.get_integration!(integration_id)

    case Map.get(integration.settings, "branches_mapping", nil) do
      nil ->
        Workers.Whippy.Writer.push_custom_object_records(
          integration,
          @initial_limit,
          dynamic([c], c.whippy_organization_id == ^integration.whippy_organization_id)
        )

      mappings ->
        Enum.each(mappings, fn mapping ->
          integration = Utils.modify_integration(integration, mapping)

          Workers.Whippy.Writer.push_custom_object_records(
            integration,
            @initial_limit,
            dynamic([c], c.whippy_organization_id == ^integration.whippy_organization_id)
          )
        end)
    end

    :ok
  end

  defp external_entity_type_to_model_mapper do
    %{
      "talent" => %Talent{},
      "avionte_contact" => %AvionteContact{},
      "companies" => %Company{},
      "placements" => %Placement{},
      "jobs" => %Jobs{}
    }
  end
end
