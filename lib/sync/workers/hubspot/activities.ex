defmodule Sync.Workers.Hubspot.Activities do
  @moduledoc """
  Handles syncing of activities to from Hubspot.

  Works both for initial syncing of all activities,
  and daily syncing of newly created activities.
  """

  use Oban.Pro.Workers.Workflow, queue: :hubspot, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_activities_from_whippy", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pulling activities from Whippy.")

    integration = Integrations.get_integration!(integration_id)

    iso_date = to_string(Date.utc_today())

    Workers.Whippy.Reader.pull_daily_whippy_messages(integration, iso_date, @initial_limit, @initial_offset)

    :ok
  end

  def process(%Job{args: %{"type" => "push_activities_to_hubspot", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pushing activities to Hubspot.")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Hubspot.Writer.push_activities()

    :ok
  end
end
