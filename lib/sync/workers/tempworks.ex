defmodule Sync.Workers.Tempworks do
  @moduledoc """
  This worker is the entrypoint for TempWorks syncing.

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

  ## Workflow Types

  The worker supports several types of sync workflows:

  1. `monthly_sync` - Syncs birthdays between TempWorks and Whippy
  2. `full_sync` - Performs a complete sync of all data
  3. `daily_sync` - Syncs daily changes
  4. `employee_daily_sync` - Syncs employee data daily
  5. `employee_custom_data_sync` - Syncs employee custom data
  6. `assignment_custom_data_sync` - Syncs assignment custom data
  7. `job_order_custom_data_sync` - Syncs job order custom data
  8. `tempworks_contacts_custom_data_sync_job` - Syncs TempWorks contacts custom data
  9. `customers_custom_data_sync_job` - Syncs customer custom data

  ## Custom Data Sync

  The worker supports syncing custom data between TempWorks and Whippy. This is controlled by
  the `sync_custom_data` setting in the integration. When enabled, additional jobs are added
  to the workflow to handle custom data synchronization.

  ## Dependencies

  The worker depends on several other modules:
  - `Sync.Integrations` - For managing integration settings
  - `Sync.Workers.Tempworks.Branches` - For syncing branch data
  - `Sync.Workers.Tempworks.CustomData` - For handling custom data
  - `Sync.Workers.Tempworks.Employees` - For syncing employee data
  - `Sync.Workers.Tempworks.Messages` - For syncing messages
  - `Sync.Workers.Tempworks.Users` - For syncing user data
  - `Sync.Workers.Utils` - For utility functions
  """
  use Oban.Pro.Workers.Workflow, queue: :tempworks, max_attempts: 3

  alias __MODULE__
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers.Tempworks.Branches
  alias Sync.Workers.Tempworks.CustomData
  alias Sync.Workers.Tempworks.Employees
  alias Sync.Workers.Tempworks.Messages
  alias Sync.Workers.Tempworks.Users
  alias Sync.Workers.Utils

  require Logger

  @worker_and_types %{
    Users => [:pull_users_from_whippy],
    Branches => [:pull_branches_from_tempworks],
    Employees => [
      :pull_employees_from_tempworks,
      :pull_contacts_from_whippy,
      :lookup_contacts_in_tempworks,
      :push_contacts_to_tempworks,
      :push_employees_to_whippy,
      :daily_pull_employees_from_tempworks,
      :daily_push_employees_to_whippy,
      :daily_pull_contacts_from_whippy,
      :daily_push_contacts_to_tempworks,
      :monthly_pull_birthdays_from_tempworks,
      :monthly_push_birthdays_to_whippy,
      :pull_contacts_from_tempworks,
      :daily_pull_contacts_from_tempworks
    ],
    Messages => [
      :pull_messages_from_whippy,
      :push_messages_to_tempworks,
      :daily_pull_messages_from_whippy,
      :daily_push_messages_to_tempworks
    ],
    CustomData.CustomObjects => [
      :pull_custom_objects_from_whippy,
      :pull_custom_objects_from_tempworks,
      :push_custom_objects_to_whippy,
      :push_custom_object_records_to_whippy
    ],
    CustomData.Employees => [
      :process_employee_details_as_custom_object_records,
      :process_employees_as_custom_object_records,
      :process_contact_details_as_custom_object_records
    ],
    CustomData.Assignments => [
      :process_assignments_as_custom_object_records,
      :process_advance_assignments_as_custom_object_records
    ],
    CustomData.JobOrders => [
      :process_job_orders_as_custom_object_records
    ],
    CustomData.Customers => [
      :process_customers_as_custom_object_records
    ]
  }

  @doc """
  Processes a monthly sync job for syncing birthdays between TempWorks and Whippy.

  ## Parameters
    - `job` - The Oban job containing:
      - `integration_id` - The ID of the TempWorks integration
      - `type` - Must be "monthly_sync"
      - `inserted_at` - When the job was inserted

  ## Returns
    - `{:ok, jobs}` - A tuple containing :ok and the list of created jobs
  """
  def process(
        %Job{args: %{"integration_id" => integration_id, "type" => "monthly_sync"}, inserted_at: job_inserted_at} = _job
      ) do
    Logger.info("Syncing birthdays to TempWorks integration #{integration_id}")

    monthly_params = %{integration_id: integration_id, day: DateTime.to_date(job_inserted_at)}

    jobs =
      Tempworks.new_workflow()
      |> add_job(:monthly_pull_birthdays_from_tempworks, monthly_params)
      |> add_job(:monthly_push_birthdays_to_whippy, monthly_params, [:monthly_pull_birthdays_from_tempworks])
      |> Oban.insert_all()

    {:ok, jobs}
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "full_sync"}} = _job) do
    Logger.info("Syncing TempWorks integration #{integration_id}")

    Tempworks.new_workflow()
    |> add_job(:pull_branches_from_tempworks, %{integration_id: integration_id})
    |> add_job(:pull_employees_from_tempworks, %{integration_id: integration_id}, [:pull_branches_from_tempworks])
    |> add_job(:pull_contacts_from_tempworks, %{integration_id: integration_id}, [:pull_employees_from_tempworks])
    |> maybe_send_contacts_to_external_integrations(%{integration_id: integration_id})
    |> add_job(:pull_messages_from_whippy, %{integration_id: integration_id}, [:push_employees_to_whippy])
    |> add_job(:push_messages_to_tempworks, %{integration_id: integration_id}, [:pull_messages_from_whippy])
    |> Oban.insert_all()

    :ok
  end

  def process(
        %Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}, inserted_at: job_inserted_at} = _job
      ) do
    Logger.info("Syncing TempWorks integration #{integration_id} for #{job_inserted_at}")
    daily_params = %{integration_id: integration_id, day: DateTime.to_date(job_inserted_at)}

    jobs =
      Tempworks.new_workflow()
      |> add_job(:pull_branches_from_tempworks, %{integration_id: integration_id})
      |> add_job(:pull_users_from_whippy, %{integration_id: integration_id}, [:pull_branches_from_tempworks])
      |> add_job(:daily_pull_employees_from_tempworks, daily_params, [:pull_branches_from_tempworks])
      |> add_job(:daily_pull_contacts_from_tempworks, daily_params, [:daily_pull_employees_from_tempworks])
      |> maybe_send_contacts_to_external_integrations_daily(daily_params)
      |> add_job(:daily_pull_messages_from_whippy, daily_params, [:daily_push_employees_to_whippy])
      |> add_job(:daily_push_messages_to_tempworks, daily_params, [:daily_pull_messages_from_whippy])
      |> maybe_add_custom_data_jobs(integration_id)
      |> Oban.insert_all()

    {:ok, jobs}
  end

  def process(
        %Job{
          args: %{"integration_id" => integration_id, "type" => "employee_custom_data_sync"},
          inserted_at: job_inserted_at
        } = _job
      ) do
    Logger.info("Syncing Employee Custom data to TempWorks integration #{integration_id}")

    employee_params = %{
      integration_id: integration_id,
      details: "employee_custom_data_sync",
      day: DateTime.to_date(job_inserted_at)
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        Tempworks.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, employee_params)
        |> add_job(:pull_custom_objects_from_tempworks, employee_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, employee_params, [:pull_custom_objects_from_tempworks])
        # Resend employees to whippy, Since we updated the birthday in the contact.
        |> add_job(:process_employee_details_as_custom_object_records, employee_params, [:push_custom_objects_to_whippy])
        |> add_job(:daily_push_employees_to_whippy, employee_params, [:process_employee_details_as_custom_object_records])
        |> add_job(:push_custom_object_records_to_whippy, employee_params, [
          :daily_push_employees_to_whippy
        ])
        |> Oban.insert_all()

      _ ->
        :ok
    end
  end

  def process(
        %Job{
          args: %{"integration_id" => integration_id, "type" => "assignment_custom_data_sync"},
          inserted_at: job_inserted_at
        } = _job
      ) do
    Logger.info("Syncing Assignment Custom data to TempWorks integration #{integration_id}")

    assignment_params = %{
      integration_id: integration_id,
      details: "assignment_custom_data_sync",
      day: DateTime.to_date(job_inserted_at)
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        Tempworks.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, assignment_params)
        |> add_job(:pull_custom_objects_from_tempworks, assignment_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, assignment_params, [:pull_custom_objects_from_tempworks])
        |> add_job(:process_assignments_as_custom_object_records, assignment_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, assignment_params, [
          :process_assignments_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        :ok
    end
  end

  def process(
        %Job{
          args: %{"integration_id" => integration_id, "type" => "job_order_custom_data_sync"},
          inserted_at: job_inserted_at
        } = _job
      ) do
    Logger.info("Syncing Job Order Custom data to TempWorks integration #{integration_id}")

    job_order_params = %{
      integration_id: integration_id,
      details: "job_order_custom_data_sync",
      day: DateTime.to_date(job_inserted_at)
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        Tempworks.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, job_order_params)
        |> add_job(:pull_custom_objects_from_tempworks, job_order_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, job_order_params, [:pull_custom_objects_from_tempworks])
        |> add_job(:process_job_orders_as_custom_object_records, job_order_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, job_order_params, [
          :process_job_orders_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        :ok
    end
  end

  def process(
        %Job{
          args: %{"integration_id" => integration_id, "type" => "tempworks_contacts_custom_data_sync_job"},
          inserted_at: job_inserted_at
        } = _job
      ) do
    Logger.info("Syncing Tempworks Contacts Custom data to TempWorks integration #{integration_id}")

    contact_params = %{
      integration_id: integration_id,
      details: "tempworks_contacts_custom_data_sync_job",
      day: DateTime.to_date(job_inserted_at)
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        Tempworks.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, contact_params)
        |> add_job(:pull_custom_objects_from_tempworks, contact_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, contact_params, [:pull_custom_objects_from_tempworks])
        |> add_job(:daily_pull_contacts_from_tempworks, contact_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_employees_to_whippy, contact_params, [:daily_pull_contacts_from_tempworks])
        |> add_job(:process_contact_details_as_custom_object_records, contact_params, [
          :push_employees_to_whippy
        ])
        |> add_job(:push_custom_object_records_to_whippy, contact_params, [
          :process_contact_details_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        :ok
    end
  end

  def process(
        %Job{
          args: %{"integration_id" => integration_id, "type" => "customers_custom_data_sync_job"},
          inserted_at: job_inserted_at
        } = _job
      ) do
    Logger.info("Syncing Tempworks Customers Custom data to TempWorks integration #{integration_id}")

    customer_params = %{
      integration_id: integration_id,
      details: "customers_custom_data_sync_job",
      day: DateTime.to_date(job_inserted_at)
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        Tempworks.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, customer_params)
        |> add_job(:pull_custom_objects_from_tempworks, customer_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, customer_params, [:pull_custom_objects_from_tempworks])
        |> add_job(:process_customers_as_custom_object_records, customer_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, customer_params, [
          :process_customers_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        :ok
    end
  end

  defp maybe_add_custom_data_jobs(workflow, integration_id) do
    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true, "use_advance_search" => use_advance_search}} ->
        add_custom_data_jobs(workflow, integration_id, use_advance_search)

      _ ->
        workflow
    end
  end

  defp add_custom_data_jobs(workflow, integration_id, use_advance_search) do
    params = %{integration_id: integration_id}

    workflow
    |> add_job(:pull_custom_objects_from_whippy, params, [:daily_push_messages_to_tempworks])
    |> add_job(:pull_custom_objects_from_tempworks, params, [:pull_custom_objects_from_whippy])
    |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_tempworks])
    |> add_employee_and_assignment_search_job(use_advance_search, params)
  end

  # when it supports advance search
  defp add_employee_and_assignment_search_job(workflow, true, params) do
    workflow
    |> add_job(:process_employees_as_custom_object_records, params, [:push_custom_objects_to_whippy])
    |> add_job(:process_advance_assignments_as_custom_object_records, params, [
      :process_employees_as_custom_object_records
    ])
    |> add_job(:push_custom_object_records_to_whippy, params, [
      :process_advance_assignments_as_custom_object_records
    ])
  end

  # when it doesn't support advance search
  defp add_employee_and_assignment_search_job(workflow, false, params) do
    workflow
    |> add_job(:process_employee_details_as_custom_object_records, params, [:push_custom_objects_to_whippy])
    |> add_job(:daily_push_employees_to_whippy, params, [:process_employee_details_as_custom_object_records])
    |> add_job(:process_assignments_as_custom_object_records, params, [
      :daily_push_employees_to_whippy
    ])
    |> add_job(:process_contact_details_as_custom_object_records, params, [
      :process_assignments_as_custom_object_records
    ])
    |> add_job(:process_job_orders_as_custom_object_records, params, [
      :process_contact_details_as_custom_object_records
    ])
    |> add_job(:process_customers_as_custom_object_records, params, [
      :process_job_orders_as_custom_object_records
    ])
    |> add_job(:push_custom_object_records_to_whippy, params, [
      :process_customers_as_custom_object_records
    ])
  end

  defp maybe_send_contacts_to_external_integrations(workflow, integration_id) do
    send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_tempworks]},
      {:lookup_contacts_in_tempworks, [:pull_contacts_from_whippy]},
      {:push_contacts_to_tempworks, [:lookup_contacts_in_tempworks]},
      {:push_employees_to_whippy, [:push_contacts_to_tempworks]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_tempworks]},
      {:lookup_contacts_in_tempworks, [:pull_contacts_from_whippy]},
      {:push_employees_to_whippy, [:lookup_contacts_in_tempworks]}
    ]

    Utils.maybe_send_contacts_to_external_integrations(
      workflow,
      integration_id,
      send_contacts,
      do_no_send_contacts,
      __MODULE__,
      @worker_and_types
    )
  end

  defp maybe_send_contacts_to_external_integrations_daily(workflow, daily_params) do
    send_contacts = [
      {:daily_pull_contacts_from_whippy, [:daily_pull_contacts_from_tempworks]},
      {:lookup_contacts_in_tempworks, [:daily_pull_contacts_from_whippy]},
      {:daily_push_contacts_to_tempworks, [:lookup_contacts_in_tempworks]},
      {:daily_push_employees_to_whippy, [:daily_push_contacts_to_tempworks]}
    ]

    do_no_send_contacts = [
      {:daily_pull_contacts_from_whippy, [:daily_pull_contacts_from_tempworks]},
      {:lookup_contacts_in_tempworks, [:daily_pull_contacts_from_whippy]},
      {:daily_push_employees_to_whippy, [:lookup_contacts_in_tempworks]}
    ]

    Utils.maybe_send_contacts_to_external_integrations(
      workflow,
      daily_params,
      send_contacts,
      do_no_send_contacts,
      __MODULE__,
      @worker_and_types
    )
  end

  ###################
  ##    Helpers    ##
  ###################
  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @worker_and_types, type, args, deps)
end
