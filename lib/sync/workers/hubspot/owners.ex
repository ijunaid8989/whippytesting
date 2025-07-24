defmodule Sync.Workers.Hubspot.Owners do
  @moduledoc """
  Handles syncing of owners to and from Hubspot.

  Works both for initial syncing of all owners,
  and daily syncing of newly created owners.
  """

  use Oban.Pro.Workers.Workflow, queue: :hubspot, max_attempts: 3

  alias Sync.Integrations
  alias Sync.Workers

  require Logger

  @initial_limit 100
  @initial_offset 0

  def process(%Job{args: %{"type" => "pull_owners_from_hubspot", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pulling owners from Hubspot.")

    integration = Integrations.get_integration!(integration_id)

    Workers.Hubspot.Reader.pull_owners(
      integration,
      ""
    )

    :ok
  end

  def process(%Job{args: %{"type" => "pull_owners_from_whippy", "integration_id" => integration_id}}) do
    Logger.info("[Hubspot] [Integration #{integration_id}] Pulling owners from Whippy")

    integration_id
    |> Integrations.get_integration!()
    |> Workers.Whippy.Reader.pull_whippy_users(@initial_limit, @initial_offset)

    :ok
  end
end
