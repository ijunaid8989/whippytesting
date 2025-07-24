defmodule Sync.Workers.TempworksFrequent do
  @moduledoc """
  This worker is the entrypoint for TempWorks messages processing.

  Each integration with TempWorks would have one job for this worker,
  which would then trigger its workflow.

  There are some caveats when syncing with TempWorks worth noting:
    - we don't want to update contacts (employees) in TempWorks that were update in Whippy;
    - making a request to create a new contact (employee) with duplicate data in TempWorks
      would create a duplicate record;
    - we want to only sync messages from Whippy to TempWorks, we don't want to sync messages
      from TempWorks to Whippy;
    - we cannot filter TempWorks contacts (employees) on timestamps;
    - we cannot specify timestamps for messages in TempWorks;
    - for the beginning, we want to chunk Whippy messages in one message for TempWorks -
      we want this to be one TempWorks message per contact per day per conversations -
      with all the contact's conversations' daily messages chunked in one.

  Notes:
    - eventually, we might want to sync Whippy channels to the Sync database,
    as a part of this workflow too. This is because we use channel data to get the timezone
    for a message, when syncing it with TempWorks.
  """

  # Use Oban Pro's Workflow functionality to handle job processing
  # Set the queue to :tempworks_frequent and allow up to 3 retry attempts
  use Oban.Pro.Workers.Workflow, queue: :tempworks_frequent, max_attempts: 3

  alias __MODULE__, as: Tempworks
  alias Sync.Workers.Tempworks.FrequentEmployees
  alias Sync.Workers.Tempworks.FrequentMessages
  alias Sync.Workers.Utils

  require Logger

  # Define the mapping between worker modules and their supported job types
  # This maps the FrequentMessages worker to its two main operations:
  # 1. Pulling messages from Whippy
  # 2. Pushing those messages to TempWorks
  @worker_and_types %{
    FrequentMessages => [
      :frequently_pull_messages_from_whippy,
      :frequently_push_messages_to_tempworks
    ],
    FrequentEmployees => [
      :sync_todays_employees
    ]
  }

  @impl true
  @doc """
  Process a messages sync job for a TempWorks integration.

  This function:
  1. Takes a job with integration_id and type "messages_sync"
  2. Creates a workflow that first pulls messages from Whippy
  3. Then pushes those messages to TempWorks
  4. Returns the created jobs

  Args:
    - integration_id: ID of the TempWorks integration
    - type: Must be "messages_sync"
    - job_inserted_at: Timestamp used to determine which day to sync
  """
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "messages_sync"}, inserted_at: job_inserted_at}) do
    Logger.info("Syncing messages to TempWorks integration #{integration_id}")

    # Create parameters for the daily sync jobs using the job's insertion date
    daily_params = %{
      integration_id: integration_id,
      day: DateTime.to_date(job_inserted_at)
    }

    # Create and insert a new workflow with two sequential jobs:
    # 1. Pull messages from Whippy
    # 2. Push messages to TempWorks (depends on step 1)
    jobs =
      Tempworks.new_workflow()
      |> add_job(:frequently_pull_messages_from_whippy, daily_params)
      |> add_job(:frequently_push_messages_to_tempworks, daily_params, [:frequently_pull_messages_from_whippy])
      |> Oban.insert_all()

    {:ok, jobs}
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "employee_frequent_sync"}} = _job) do
    Logger.info("Syncing Frequent TempWorks Employees for integration #{integration_id}")

    jobs =
      Tempworks.new_workflow()
      |> add_job(:sync_todays_employees, %{integration_id: integration_id})
      |> Oban.insert_all()

    {:ok, jobs}
  end

  ###################
  ##    Helpers    ##
  ###################
  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @worker_and_types, type, args, deps)
end
