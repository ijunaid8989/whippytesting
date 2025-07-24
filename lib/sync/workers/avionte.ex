defmodule Sync.Workers.Avionte do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :avionte, max_attempts: 3

  alias __MODULE__
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers.Avionte.AvionteContacts
  alias Sync.Workers.Avionte.Branches
  alias Sync.Workers.Avionte.CustomData
  alias Sync.Workers.Avionte.TalentActivities
  alias Sync.Workers.Avionte.Talents
  alias Sync.Workers.Avionte.Users
  alias Sync.Workers.Utils

  require Logger

  @users_types [
    :pull_users_from_avionte,
    :pull_users_from_whippy
  ]

  @talent_activities_types [
    :pull_messages_from_whippy,
    :push_talent_activities_to_avionte,
    :daily_pull_messages_from_whippy,
    :daily_push_talent_activities_to_avionte
  ]

  @talents_types [
    :pull_talents_from_avionte,
    :pull_contacts_from_whippy,
    :push_contacts_to_avionte,
    :push_talents_to_whippy
  ]

  @branches_types [:pull_branches_from_avionte]

  @custom_objects_types [
    :pull_custom_objects_from_whippy,
    :pull_custom_objects_from_avionte,
    :push_custom_objects_to_whippy,
    :push_custom_object_records_to_whippy
  ]

  @custom_data_talents_types [
    :process_talents_as_custom_object_records
  ]

  @custom_data_contacts_types [
    :process_contacts_as_custom_object_records
  ]

  @contacts_types [
    :pull_contacts_from_avionte
  ]

  @companies_types [
    :process_companies_as_custom_object_records
  ]

  @placements_types [
    :process_placements_as_custom_object_records
  ]

  @jobs_types [
    :process_jobs_as_custom_object_records
  ]

  @worker_and_types %{
    Users => @users_types,
    TalentActivities => @talent_activities_types,
    Talents => @talents_types,
    Branches => @branches_types,
    CustomData.CustomObjects => @custom_objects_types,
    CustomData.Talents => @custom_data_talents_types,
    AvionteContacts => @contacts_types,
    CustomData.AvionteContacts => @custom_data_contacts_types,
    CustomData.AvionteCompanies => @companies_types,
    CustomData.Placements => @placements_types,
    CustomData.Jobs => @jobs_types
  }

  @doc """
  Creates a new Avionte workflow with jobs that need to be executed to sync Avionte data into Whippy.

  There are three types of syncs:
  - full_sync: Pulls all the data from Avionte and Whippy, including old messages.
  - daily_sync: Pulls the data from Avionte and Whippy, excluding old messages.
  - messages_sync: Pulls only the newly created messages from Whippy and pushes them to Avionte.

  Note: The order of the jobs is important. The jobs are executed in the order they are added to the workflow.
  The job that pulls users from Whippy should be added before the job that pulls users from Avionte, this avoids
  raising an error when trying to save a user that already exists in the database.
  """
  @impl true
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "full_sync"}} = _job) do
    Logger.info("Syncing Avionte integration #{integration_id}")

    Avionte.new_workflow()
    |> add_job(:pull_branches_from_avionte, %{integration_id: integration_id})
    |> add_job(:pull_users_from_whippy, %{integration_id: integration_id}, [:pull_branches_from_avionte])
    |> add_job(:pull_users_from_avionte, %{integration_id: integration_id}, [:pull_users_from_whippy])
    |> add_job(:pull_talents_from_avionte, %{integration_id: integration_id}, [:pull_users_from_avionte])
    |> add_job(:pull_contacts_from_avionte, %{integration_id: integration_id}, [:pull_talents_from_avionte])
    |> maybe_send_contacts_to_external_integrations(%{integration_id: integration_id})
    |> Utils.maybe_add_custom_data_jobs(integration_id, &add_custom_data_jobs/2)
    |> Oban.insert_all()

    :ok
  end

  def process(
        %Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}, inserted_at: job_inserted_at} = _job
      ) do
    Logger.info("Syncing Avionte integration daily sync #{integration_id}")

    sync_date = DateTime.to_date(job_inserted_at)

    Avionte.new_workflow()
    |> maybe_send_contacts_to_external_integrations_daily(%{integration_id: integration_id, day: sync_date})
    |> Oban.insert_all()

    :ok
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "custom_data_sync"}}) do
    Logger.info("[Integration][#{integration_id}] custom data sync and pushing them to Whippy ")

    params = %{integration_id: integration_id}

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, params, [])
        |> add_job(:pull_custom_objects_from_avionte, params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_talents_as_custom_object_records, params, [:push_custom_objects_to_whippy])
        |> add_job(:process_contacts_as_custom_object_records, params, [:process_talents_as_custom_object_records])
        |> add_job(:process_companies_as_custom_object_records, params, [:process_contacts_as_custom_object_records])
        |> add_job(:process_placements_as_custom_object_records, params, [:process_companies_as_custom_object_records])
        |> add_job(:process_jobs_as_custom_object_records, params, [:process_placements_as_custom_object_records])
        |> add_job(:push_custom_object_records_to_whippy, params, [:process_jobs_as_custom_object_records])
        |> Oban.insert_all()

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, params, [])
        |> add_job(:pull_custom_objects_from_avionte, params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_talents_as_custom_object_records, params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, params, [:process_talents_as_custom_object_records])
        |> Oban.insert_all()
    end

    :ok
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "talents_custom_data_sync"}} = _job) do
    Logger.info("Syncing Talent Custom data to Avionte integration #{integration_id}")

    talent_params = %{
      integration_id: integration_id
    }

    Avionte.new_workflow()
    |> add_job(:pull_custom_objects_from_whippy, talent_params)
    |> add_job(:pull_custom_objects_from_avionte, talent_params, [:pull_custom_objects_from_whippy])
    |> add_job(:push_custom_objects_to_whippy, talent_params, [:pull_custom_objects_from_avionte])
    |> add_job(:process_talents_as_custom_object_records, talent_params, [:push_custom_objects_to_whippy])
    |> add_job(:push_custom_object_records_to_whippy, talent_params, [
      :process_talents_as_custom_object_records
    ])
    |> Oban.insert_all()
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "avionte_contacts_custom_data_sync"}} = _job) do
    Logger.info("Syncing Avionte Contacts Custom data to Avionte integration #{integration_id}")

    talent_params = %{
      integration_id: integration_id
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, talent_params)
        |> add_job(:pull_custom_objects_from_avionte, talent_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, talent_params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_contacts_as_custom_object_records, talent_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, talent_params, [
          :process_contacts_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        :ok
    end
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "avionte_companies_custom_data_sync"}} = _job) do
    Logger.info("Syncing Avionte Companies Custom data to Avionte integration #{integration_id}")

    talent_params = %{
      integration_id: integration_id
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, talent_params)
        |> add_job(:pull_custom_objects_from_avionte, talent_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, talent_params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_companies_as_custom_object_records, talent_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, talent_params, [
          :process_companies_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        :ok
    end
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "avionte_placements_custom_data_sync"}} = _job) do
    Logger.info("Syncing Avionte Placements Custom data to Avionte integration #{integration_id}")

    talent_params = %{
      integration_id: integration_id
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, talent_params)
        |> add_job(:pull_custom_objects_from_avionte, talent_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, talent_params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_placements_as_custom_object_records, talent_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, talent_params, [
          :process_placements_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        :ok
    end
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "avionte_jobs_custom_data_sync"}} = _job) do
    Logger.info("Syncing Avionte Jobs Custom data to Avionte integration #{integration_id}")

    talent_params = %{
      integration_id: integration_id
    }

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        Avionte.new_workflow()
        |> add_job(:pull_custom_objects_from_whippy, talent_params)
        |> add_job(:pull_custom_objects_from_avionte, talent_params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, talent_params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_jobs_as_custom_object_records, talent_params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, talent_params, [
          :process_jobs_as_custom_object_records
        ])
        |> Oban.insert_all()

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        :ok
    end
  end

  defp add_custom_data_jobs(workflow, integration_id) do
    params = %{integration_id: integration_id}

    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"allow_advanced_custom_data" => true}} ->
        Logger.info("[Integration][#{integration_id}] Allowing advanced custom data")

        workflow
        |> add_job(:pull_custom_objects_from_whippy, params, [:push_talents_to_whippy])
        |> add_job(:pull_custom_objects_from_avionte, params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_talents_as_custom_object_records, params, [:push_custom_objects_to_whippy])
        |> add_job(:process_contacts_as_custom_object_records, params, [:process_talents_as_custom_object_records])
        |> add_job(:process_companies_as_custom_object_records, params, [:process_contacts_as_custom_object_records])
        |> add_job(:process_placements_as_custom_object_records, params, [:process_companies_as_custom_object_records])
        |> add_job(:process_jobs_as_custom_object_records, params, [:process_placements_as_custom_object_records])
        |> add_job(:push_custom_object_records_to_whippy, params, [:process_jobs_as_custom_object_records])

      _ ->
        Logger.info("[Integration][#{integration_id}] Not allowing advanced custom data")

        workflow
        |> add_job(:pull_custom_objects_from_whippy, params, [:push_talents_to_whippy])
        |> add_job(:pull_custom_objects_from_avionte, params, [:pull_custom_objects_from_whippy])
        |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_avionte])
        |> add_job(:process_talents_as_custom_object_records, params, [:push_custom_objects_to_whippy])
        |> add_job(:push_custom_object_records_to_whippy, params, [:process_talents_as_custom_object_records])
    end
  end

  defp maybe_send_contacts_to_external_integrations(workflow, integration_id) do
    send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_avionte]},
      {:push_contacts_to_avionte, [:pull_contacts_from_whippy]},
      {:push_talents_to_whippy, [:pull_talents_from_avionte]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_avionte]},
      {:push_talents_to_whippy, [:pull_contacts_from_whippy]}
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
      {:pull_contacts_from_whippy, []},
      {:push_contacts_to_avionte, [:pull_contacts_from_whippy]},
      {:daily_pull_messages_from_whippy, [:push_contacts_to_avionte]},
      {:daily_push_talent_activities_to_avionte, [:daily_pull_messages_from_whippy]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, []},
      {:daily_pull_messages_from_whippy, [:pull_contacts_from_whippy]},
      {:daily_push_talent_activities_to_avionte, [:daily_pull_messages_from_whippy]}
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
