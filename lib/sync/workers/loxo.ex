defmodule Sync.Workers.Loxo do
  @moduledoc false
  use Oban.Pro.Workers.Workflow, queue: :loxo, max_attempts: 3

  alias __MODULE__
  alias Sync.Workers.Loxo.People
  alias Sync.Workers.Loxo.PersonEvents
  alias Sync.Workers.Loxo.Users
  alias Sync.Workers.Utils

  require Logger

  @contacts_types [
    :pull_contacts_from_whippy,
    :pull_people_from_loxo,
    :push_contacts_to_loxo,
    :push_people_to_whippy
  ]

  @person_events_types [
    :daily_pull_messages_from_whippy,
    :daily_push_person_activities_to_loxo,
    :pull_messages_from_whippy,
    :push_person_activities_to_loxo
  ]

  @user_types [:pull_users_from_loxo, :pull_users_from_whippy]

  @worker_and_types %{
    People => @contacts_types,
    PersonEvents => @person_events_types,
    Users => @user_types
  }

  @impl true
  def process(
        %Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}, inserted_at: job_inserted_at} = _job
      ) do
    Logger.info("Processing Loxo daily sync for integration #{integration_id}")

    sync_date =
      DateTime.to_date(job_inserted_at)

    jobs =
      Loxo.new_workflow()
      |> add_job(:pull_users_from_whippy, %{integration_id: integration_id})
      |> add_job(:pull_users_from_loxo, %{integration_id: integration_id}, [
        :pull_users_from_whippy
      ])
      |> add_job(:pull_people_from_loxo, %{integration_id: integration_id}, [
        :pull_users_from_loxo
      ])
      |> add_job(:pull_contacts_from_whippy, %{integration_id: integration_id}, [
        :pull_people_from_loxo
      ])
      |> add_job(:push_contacts_to_loxo, %{integration_id: integration_id}, [
        :pull_contacts_from_whippy
      ])
      |> add_job(:push_people_to_whippy, %{integration_id: integration_id}, [
        :push_contacts_to_loxo
      ])
      |> add_job(
        :daily_pull_messages_from_whippy,
        %{integration_id: integration_id, day: sync_date},
        [
          :push_people_to_whippy
        ]
      )
      |> add_job(
        :daily_push_person_activities_to_loxo,
        %{integration_id: integration_id, day: sync_date},
        [
          :daily_pull_messages_from_whippy
        ]
      )
      |> Oban.insert_all()

    {:ok, jobs}
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "full_sync"}} = _job) do
    Logger.info("Processing Loxo full sync for integration #{integration_id}")

    Loxo.new_workflow()
    |> add_job(:pull_users_from_whippy, %{integration_id: integration_id})
    |> add_job(:pull_users_from_loxo, %{integration_id: integration_id}, [:pull_users_from_whippy])
    |> add_job(:pull_people_from_loxo, %{integration_id: integration_id}, [:pull_users_from_loxo])
    |> add_job(:pull_contacts_from_whippy, %{integration_id: integration_id}, [:pull_people_from_loxo])
    |> add_job(:push_contacts_to_loxo, %{integration_id: integration_id}, [:pull_contacts_from_whippy])
    |> add_job(:push_people_to_whippy, %{integration_id: integration_id}, [:pull_people_from_loxo])
    |> add_job(:pull_messages_from_whippy, %{integration_id: integration_id}, [:push_people_to_whippy])
    |> add_job(:push_person_activities_to_loxo, %{integration_id: integration_id}, [:pull_messages_from_whippy])
    |> Oban.insert_all()

    :ok
  end

  def process(job) do
    Logger.info("No job matched input job in Loxo: #{inspect(job)}")

    :ok
  end

  ###################
  ##    Helpers    ##
  ###################

  # Adds a job to the workflow with the given type, args, and dependencies.
  # If the type is unknown, an ArgumentError is raised.
  @spec add_job(Workflow.t(), atom(), map(), list()) :: Workflow.t()
  defp add_job(workflow, type, args, deps \\ []),
    do: Utils.add_job(workflow, __MODULE__, @worker_and_types, type, args, deps)
end
