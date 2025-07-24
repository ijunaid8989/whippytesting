defmodule Sync.Workers.AvionteMessages do
  @moduledoc """
  This worker is the entrypoint for Avionte messages processing.

  Each integration with Avionte has one job for this worker which triggers its workflow.

  The workflow handles syncing messages between Whippy and Avionte:
  - Pulls messages from Whippy and pushes them to Avionte as talent activities
  - Messages are synced daily, with one job per integration
  - Messages are processed in batches with configurable limits and offsets
  - The workflow ensures messages are processed in order by using job dependencies
  """
  use Oban.Pro.Workers.Workflow, queue: :avionte_messages, max_attempts: 3

  alias __MODULE__
  alias Sync.Workers.Avionte.FrequentTalentActivities
  alias Sync.Workers.Utils

  require Logger

  # Constants for job types and worker mappings
  @job_types [
    :pull_messages_from_whippy,
    :push_talent_activities_to_avionte,
    :daily_pull_messages_from_whippy,
    :daily_push_talent_activities_to_avionte
  ]

  # Map of worker modules to their supported job types
  # This allows us to easily look up which worker handles which job type
  @worker_mapping %{
    FrequentTalentActivities => @job_types
  }

  @doc """
  Processes a messages sync job for an Avionte integration.

  This function is the main entry point for the workflow and is called by Oban when a new
  messages_sync job is ready to be processed. It:

  1. Creates a new workflow instance
  2. Adds a job to pull today's messages from Whippy
  3. Adds a dependent job to push those messages to Avionte
  4. Submits the workflow to Oban for processing

  The workflow ensures messages are processed in order by making the push job dependent
  on the successful completion of the pull job.

  ## Parameters
    * job - An Oban.Job struct containing:
      * args: A map with:
        * "integration_id" - ID of the Avionte integration to sync
        * "type" - Must be "messages_sync"
      * inserted_at - Timestamp used to determine the sync date

  ## Returns
    * :ok - On successful workflow creation and submission

  ## Examples

      process(%Job{
        args: %{
          "integration_id" => "123",
          "type" => "messages_sync"
        },
        inserted_at: ~U[2023-01-01 00:00:00Z]
      })
      :ok
  """
  @impl true
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "messages_sync"}, inserted_at: job_inserted_at}) do
    Logger.info("Syncing frequent messages to Avionte integration #{integration_id}")

    # Get today's date from the job's insertion timestamp
    sync_date = DateTime.to_date(job_inserted_at)

    # Create and configure the workflow
    AvionteMessages.new_workflow()
    |> add_pull_messages_job(integration_id, sync_date)
    |> add_push_messages_job(integration_id, sync_date)
    |> Oban.insert_all()

    :ok
  end

  ###################
  ##    Helpers    ##
  ###################

  defp add_pull_messages_job(workflow, integration_id, sync_date) do
    add_job(workflow, :daily_pull_messages_from_whippy, %{
      integration_id: integration_id,
      day: sync_date
    })
  end

  defp add_push_messages_job(workflow, integration_id, sync_date) do
    add_job(
      workflow,
      :daily_push_talent_activities_to_avionte,
      %{integration_id: integration_id, day: sync_date},
      [:daily_pull_messages_from_whippy]
    )
  end

  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @worker_mapping, type, args, deps)
end
