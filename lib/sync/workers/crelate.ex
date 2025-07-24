defmodule Sync.Workers.Crelate do
  @moduledoc """
  This worker is the entrypoint for Crelate syncing.

  Each integration with Crelate would have one job for this worker,
  which would then trigger its workflow.
  """
  use Oban.Pro.Workers.Workflow, queue: :crelate, max_attempts: 3

  alias __MODULE__
  alias Sync.Workers.Crelate.Activities
  alias Sync.Workers.Crelate.Entities
  alias Sync.Workers.Utils

  require Logger

  @worker_and_types %{
    Entities => [
      :pull_contacts_from_crelate,
      :pull_contacts_from_whippy,
      :push_contacts_to_crelate,
      :push_contacts_to_whippy,
      :daily_pull_contacts_from_crelate,
      :daily_pull_contacts_from_whippy,
      :daily_push_contacts_to_crelate,
      :daily_push_contacts_to_whippy
    ],
    Activities => [
      :pull_messages_from_whippy,
      :push_messages_to_crelate,
      :frequently_push_messages_to_crelate,
      :daily_pull_messages_from_whippy,
      :daily_push_messages_to_crelate
    ]
  }

  @impl true
  def process(%Job{args: %{"integration_id" => integration_id, "type" => "messages_sync"}, inserted_at: job_inserted_at}) do
    Logger.info("Syncing messages to Crelate integration #{integration_id}")

    daily_params = %{integration_id: integration_id, day: DateTime.to_date(job_inserted_at)}

    jobs =
      Crelate.new_workflow()
      |> add_job(:daily_pull_messages_from_whippy, daily_params)
      |> add_job(:frequently_push_messages_to_crelate, daily_params, [:daily_pull_messages_from_whippy])
      |> Oban.insert_all()

    {:ok, jobs}
  end

  def process(%Job{args: %{"integration_id" => integration_id, "type" => "full_sync"}} = _job) do
    Logger.info("Syncing Crelate integration #{integration_id}")

    Crelate.new_workflow()
    |> add_job(:pull_contacts_from_crelate, %{integration_id: integration_id})
    |> maybe_send_contacts_to_external_integrations(%{integration_id: integration_id})
    |> add_job(:pull_messages_from_whippy, %{integration_id: integration_id}, [:push_contacts_to_whippy])
    |> add_job(:push_messages_to_crelate, %{integration_id: integration_id}, [:pull_messages_from_whippy])
    |> Oban.insert_all()

    :ok
  end

  def process(
        %Job{args: %{"integration_id" => integration_id, "type" => "daily_sync"}, inserted_at: job_inserted_at} = _job
      ) do
    Logger.info("Syncing Crelate integration #{integration_id} for #{job_inserted_at}")
    daily_params = %{integration_id: integration_id, day: DateTime.to_date(job_inserted_at)}

    jobs =
      Crelate.new_workflow()
      |> add_job(:daily_pull_contacts_from_crelate, daily_params)
      |> maybe_send_contacts_to_external_integrations_daily(daily_params)
      |> add_job(:daily_pull_messages_from_whippy, daily_params, [:daily_push_contacts_to_whippy])
      |> add_job(:daily_push_messages_to_crelate, daily_params, [:daily_pull_messages_from_whippy])
      |> Oban.insert_all()

    {:ok, jobs}
  end

  defp maybe_send_contacts_to_external_integrations(workflow, integration_id) do
    send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_crelate]},
      {:push_contacts_to_crelate, [:pull_contacts_from_whippy]},
      {:push_contacts_to_whippy, [:pull_contacts_from_crelate]}
    ]

    do_no_send_contacts = [
      {:pull_contacts_from_whippy, [:pull_contacts_from_crelate]},
      {:push_contacts_to_whippy, [:pull_contacts_from_whippy]}
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
      {:daily_pull_contacts_from_whippy, [:daily_pull_contacts_from_crelate]},
      {:daily_push_contacts_to_crelate, [:daily_pull_contacts_from_whippy]},
      {:daily_push_contacts_to_whippy, [:daily_pull_contacts_from_crelate]}
    ]

    do_no_send_contacts = [
      {:daily_pull_contacts_from_whippy, [:daily_pull_contacts_from_crelate]},
      {:daily_push_contacts_to_whippy, [:daily_pull_contacts_from_whippy]}
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
