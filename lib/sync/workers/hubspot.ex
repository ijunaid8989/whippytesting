defmodule Sync.Workers.Hubspot do
  @moduledoc """
  This worker is the entrypoint for Hubspot syncing.
  """
  use Oban.Pro.Workers.Workflow, queue: :hubspot, max_attempts: 3

  alias __MODULE__
  alias Sync.Workers.Hubspot.Activities
  alias Sync.Workers.Hubspot.Contacts
  alias Sync.Workers.Hubspot.Owners
  alias Sync.Workers.Hubspot.Webhooks
  alias Sync.Workers.Utils

  require Logger

  @contact_types [
    :pull_contacts_from_hubspot,
    :pull_contacts_from_whippy,
    :push_contacts_to_hubspot,
    :push_contacts_to_whippy
  ]

  @activity_types [
    :pull_activities_from_whippy,
    :push_activities_to_hubspot
  ]

  @owner_types [
    :pull_owners_from_hubspot,
    :pull_owners_from_whippy
  ]

  @webhook_types [
    :subscribe_to_webhooks
  ]

  @workers_and_types %{
    Contacts => @contact_types,
    Activities => @activity_types,
    Owners => @owner_types,
    Webhooks => @webhook_types
  }

  @impl true
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "initial_sync"}}) do
    Logger.info("Syncing from Hubspot integration #{integration_id}")

    Hubspot.new_workflow()
    |> add_job(:pull_owners_from_hubspot, %{integration_id: integration_id})
    |> add_job(:pull_owners_from_whippy, %{integration_id: integration_id}, [:pull_owners_from_hubspot])
    |> add_job(:pull_contacts_from_hubspot, %{integration_id: integration_id}, [:pull_owners_from_whippy])
    |> add_job(:pull_contacts_from_whippy, %{integration_id: integration_id}, [:pull_contacts_from_hubspot])
    |> add_job(:push_contacts_to_whippy, %{integration_id: integration_id}, [:pull_contacts_from_whippy])
    |> add_job(:push_contacts_to_hubspot, %{integration_id: integration_id}, [:push_contacts_to_whippy])
    |> add_job(:subscribe_to_webhooks, %{integration_id: integration_id}, [:push_contacts_to_hubspot])
    |> Oban.insert_all()

    :ok
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}}) do
    Logger.info("Syncing from Hubspot integration #{integration_id}")

    Hubspot.new_workflow()
    |> add_job(:pull_activities_from_whippy, %{integration_id: integration_id})
    |> add_job(:push_activities_to_hubspot, %{integration_id: integration_id}, [:pull_activities_from_whippy])
    |> Oban.insert_all()

    :ok
  end

  ###################
  ##    Helpers    ##
  ###################

  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @workers_and_types, type, args, deps)
end
