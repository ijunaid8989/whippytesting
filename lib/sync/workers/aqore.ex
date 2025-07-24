defmodule Sync.Workers.Aqore do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :aqore, max_attempts: 3

  alias __MODULE__
  alias Sync.Workers.Aqore.Candidates
  alias Sync.Workers.Aqore.Comments
  alias Sync.Workers.Aqore.Contacts
  alias Sync.Workers.Aqore.CustomData
  alias Sync.Workers.Aqore.Users
  alias Sync.Workers.Utils

  require Logger

  @custom_objects_types [
    :pull_custom_objects_from_whippy,
    :pull_custom_objects_from_aqore,
    :push_custom_objects_to_whippy,
    :push_custom_object_records_to_whippy
  ]

  @custom_data_candidate_types [
    :process_candidates_as_custom_object_records
  ]

  @custom_data_job_candidate_types [
    :process_job_candidates_as_custom_object_records,
    :process_daily_job_candidates_as_custom_object_records
  ]

  @custom_data_job_types [
    :process_jobs_as_custom_object_records,
    :process_daily_jobs_as_custom_object_records
  ]
  @custom_data_assignment_types [
    :process_assignments_as_custom_object_records,
    :process_daily_assignments_as_custom_object_records
  ]
  @custom_data_organization_data_types [
    :process_organization_data_as_custom_object_records,
    :process_daily_organization_data_as_custom_object_records
  ]
  @custom_data_contact_types [
    :process_contacts_as_custom_object_records
  ]

  @contact_types [
    :pull_candidates_from_aqore,
    :daily_pull_candidates_from_aqore,
    :pull_contacts_from_whippy,
    :lookup_candidates_in_aqore,
    :push_contacts_to_aqore,
    :push_candidates_to_whippy
  ]

  @aqore_contact_types [
    :pull_contacts_from_aqore,
    :daily_pull_contacts_from_aqore
  ]

  @message_types [
    :pull_messages_from_whippy,
    :push_messages_to_aqore,
    :daily_pull_messages_from_whippy,
    :daily_push_comments_to_aqore,
    :frequently_push_messages_to_aqore,
    :frequently_pull_messages_from_whippy
  ]

  @user_types [
    :pull_users_from_aqore,
    :daily_pull_users_from_aqore,
    :pull_users_from_whippy
  ]

  @workers_and_types %{
    Contacts => @aqore_contact_types,
    Candidates => @contact_types,
    Comments => @message_types,
    Users => @user_types,
    CustomData.CustomObjects => @custom_objects_types,
    CustomData.Candidates => @custom_data_candidate_types,
    CustomData.JobCandidates => @custom_data_job_candidate_types,
    CustomData.Jobs => @custom_data_job_types,
    CustomData.Assignments => @custom_data_assignment_types,
    CustomData.AqoreOrganizationData => @custom_data_organization_data_types,
    CustomData.AqoreContacts => @custom_data_contact_types
  }

  @excluded_integrations_for_job_sync [
    # Laborworks - Aqore
    "5d17426f-40bf-47a6-bbec-caeeab276326"
  ]
  @impl true
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "full_sync"}}) do
    Logger.info("Full sync for integration", integration_id: integration_id, integration_client: :aqore)

    Aqore.new_workflow()
    |> add_job(:pull_users_from_whippy, %{integration_id: integration_id})
    |> add_job(:pull_users_from_aqore, %{integration_id: integration_id}, [:pull_users_from_whippy])
    |> add_job(:pull_candidates_from_aqore, %{integration_id: integration_id}, [:pull_users_from_aqore])
    |> add_job(:pull_contacts_from_aqore, %{integration_id: integration_id}, [:pull_candidates_from_aqore])
    |> maybe_send_contacts_to_external_integrations(integration_id)
    |> add_job(:pull_messages_from_whippy, %{integration_id: integration_id}, [:push_candidates_to_whippy])
    |> add_job(:push_messages_to_aqore, %{integration_id: integration_id}, [:pull_messages_from_whippy])
    |> Utils.maybe_add_custom_data_jobs(integration_id, &add_custom_data_jobs/2)
    |> Oban.insert_all()
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}, inserted_at: job_inserted_at}) do
    Logger.info("Daily sync for integration", integration_id: integration_id, integration_client: :aqore)

    sync_date = DateTime.to_date(job_inserted_at)

    Aqore.new_workflow()
    |> add_job(:pull_users_from_whippy, %{integration_id: integration_id})
    |> add_job(:daily_pull_users_from_aqore, %{integration_id: integration_id}, [:pull_users_from_whippy])
    |> add_job(:daily_pull_candidates_from_aqore, %{integration_id: integration_id, sync_date: sync_date}, [
      :daily_pull_users_from_aqore
    ])
    |> add_job(:daily_pull_contacts_from_aqore, %{integration_id: integration_id, sync_date: sync_date}, [
      :daily_pull_candidates_from_aqore
    ])
    |> maybe_send_contacts_to_external_integrations_daily(integration_id, sync_date)
    |> Utils.maybe_add_custom_data_jobs(integration_id, &add_custom_data_daily_jobs/2)
    |> Oban.insert_all()
  end

  defp add_custom_data_jobs(workflow, integration_id) do
    params = %{integration_id: integration_id}

    workflow
    |> add_job(:pull_custom_objects_from_whippy, params, [:push_candidates_to_whippy])
    |> add_job(:pull_custom_objects_from_aqore, params, [:pull_custom_objects_from_whippy])
    |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_aqore])
    |> add_job(:process_candidates_as_custom_object_records, params, [
      :push_custom_objects_to_whippy
    ])
    |> add_job(:process_contacts_as_custom_object_records, params, [
      :process_candidates_as_custom_object_records
    ])
    |> add_job(:process_organization_data_as_custom_object_records, params, [
      :process_contacts_as_custom_object_records
    ])
    |> add_job(:process_job_candidates_as_custom_object_records, params, [
      :process_organization_data_as_custom_object_records
    ])
    |> maybe_process_jobs_as_custom_object_records(params)
    |> add_job(:push_custom_object_records_to_whippy, params, [
      :process_assignments_as_custom_object_records
    ])
  end

  # Skip job and call assignments
  defp maybe_process_jobs_as_custom_object_records(workflow, %{integration_id: integration_id} = params)
       when integration_id in @excluded_integrations_for_job_sync do
    add_job(workflow, :process_assignments_as_custom_object_records, params, [
      :process_job_candidates_as_custom_object_records
    ])
  end

  # Add Job and assignments
  defp maybe_process_jobs_as_custom_object_records(workflow, %{integration_id: integration_id} = params)
       when integration_id not in @excluded_integrations_for_job_sync do
    workflow
    |> add_job(:process_jobs_as_custom_object_records, params, [
      :process_job_candidates_as_custom_object_records
    ])
    |> add_job(:process_assignments_as_custom_object_records, params, [
      :process_jobs_as_custom_object_records
    ])
  end

  # Skip job and call assignments
  defp maybe_process_jobs_as_custom_object_records_daily(workflow, %{integration_id: integration_id} = params)
       when integration_id in @excluded_integrations_for_job_sync do
    add_job(workflow, :process_daily_assignments_as_custom_object_records, params, [
      :process_daily_job_candidates_as_custom_object_records
    ])
  end

  # Add Job and assignments
  defp maybe_process_jobs_as_custom_object_records_daily(workflow, %{integration_id: integration_id} = params)
       when integration_id not in @excluded_integrations_for_job_sync do
    workflow
    |> add_job(:process_daily_jobs_as_custom_object_records, params, [
      :process_daily_job_candidates_as_custom_object_records
    ])
    |> add_job(:process_daily_assignments_as_custom_object_records, params, [
      :process_daily_job_candidates_as_custom_object_records
    ])
  end

  defp add_custom_data_daily_jobs(workflow, integration_id) do
    params = %{integration_id: integration_id}

    workflow
    |> add_job(:pull_custom_objects_from_whippy, params, [:push_candidates_to_whippy])
    |> add_job(:pull_custom_objects_from_aqore, params, [:pull_custom_objects_from_whippy])
    |> add_job(:push_custom_objects_to_whippy, params, [:pull_custom_objects_from_aqore])
    |> add_job(:process_candidates_as_custom_object_records, params, [
      :push_custom_objects_to_whippy
    ])
    |> add_job(:process_contacts_as_custom_object_records, params, [
      :process_candidates_as_custom_object_records
    ])
    |> add_job(:process_daily_organization_data_as_custom_object_records, params, [
      :process_contacts_as_custom_object_records
    ])
    |> add_job(:process_daily_job_candidates_as_custom_object_records, params, [
      :process_daily_organization_data_as_custom_object_records
    ])
    |> maybe_process_jobs_as_custom_object_records_daily(params)
    |> add_job(:push_custom_object_records_to_whippy, params, [
      :process_daily_assignments_as_custom_object_records
    ])
  end

  defp maybe_send_contacts_to_external_integrations(workflow, integration_id) do
    send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_aqore]},
      {:lookup_candidates_in_aqore, [:pull_contacts_from_whippy]},
      {:push_contacts_to_aqore, [:lookup_candidates_in_aqore]},
      {:push_candidates_to_whippy, [:push_contacts_to_aqore]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_aqore]},
      {:lookup_candidates_in_aqore, [:pull_contacts_from_whippy]},
      {:push_candidates_to_whippy, [:lookup_candidates_in_aqore]}
    ]

    Utils.maybe_send_contacts_to_external_integrations(
      workflow,
      %{integration_id: integration_id},
      send_contacts,
      do_no_send_contacts,
      __MODULE__,
      @workers_and_types
    )
  end

  defp maybe_send_contacts_to_external_integrations_daily(workflow, integration_id, sync_date) do
    send_contacts = [
      {:pull_contacts_from_whippy, [:daily_pull_contacts_from_aqore]},
      {:lookup_candidates_in_aqore, [:pull_contacts_from_whippy]},
      {:push_contacts_to_aqore, [:lookup_candidates_in_aqore]},
      {:push_candidates_to_whippy, [:push_contacts_to_aqore]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, [:daily_pull_contacts_from_aqore]},
      {:lookup_candidates_in_aqore, [:pull_contacts_from_whippy]},
      {:push_candidates_to_whippy, [:lookup_candidates_in_aqore]}
    ]

    # params =
    #   if sync_date == nil do
    #     %{integration_id: integration_id}
    #   else
    #     %{integration_id: integration_id, day: sync_date}
    #   end

    Utils.maybe_send_contacts_to_external_integrations(
      workflow,
      %{integration_id: integration_id, day: sync_date},
      send_contacts,
      do_no_send_contacts,
      __MODULE__,
      @workers_and_types
    )
  end

  ###################
  ##    Helpers    ##
  ###################

  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @workers_and_types, type, args, deps)
end
