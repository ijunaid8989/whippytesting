defmodule Oban.Pro.Plugins.DynamicLifeline do
  @moduledoc """
  The `DynamicLifeline` plugin uses producer records to periodically rescues orphaned jobs, i.e.
  jobs that are stuck in the `executing` state because the node was shut down before the job could
  finish. In addition, it will rescue stuck workflows with deleted dependencies or missed
  scheduling events.

  Without `DynamicLifeline` you'll need to manually rescue jobs stuck in the `executing` state.

  ## Using the Plugin

  To use the `DynamicLifeline` plugin, add the module to your list of Oban plugins in
  `config.exs`:

  ```elixir
  config :my_app, Oban,
    plugins: [Oban.Pro.Plugins.DynamicLifeline]
    ...
  ```

  There isn't any configuration necessary. By default, the plugin rescues orphaned jobs every 1
  minute. If necessary, you can override the rescue interval:

  ```elixir
  plugins: [{Oban.Pro.Plugins.DynamicLifeline, rescue_interval: :timer.minutes(5)}]
  ```

  If your system is under high load or produces a multitude of orphans you may wish to increase
  the query timeout beyond the `30s` default:

  ```elixir
  plugins: [{Oban.Pro.Plugins.DynamicLifeline, timeout: :timer.minutes(1)}]
  ```

  Note that rescuing orphans relies on producer records as used by the `Smart` engine.

  ## Identifying Rescued Jobs

  Rescued jobs can be identified by a `rescued` value in `meta`. Each rescue increments the
  `rescued` count by one.

  ## Rescuing Exhausted Jobs

  When a job's `attempt` matches its `max_attempts` its retries are considered "exhausted".
  Normally, the `DynamicLifeline` plugin transitions exhausted jobs to the `discarded` state and
  they won't be retried again. It does this for a couple of reasons:

  1. To ensure at-most-once semantics. Suppose a long-running job interacted with a non-idempotent
     service and was shut down while waiting for a reply; you may not want that job to retry.

  2. To prevent infinitely crashing BEAM nodes. Poorly behaving jobs may crash the node (through
     NIFs, memory exhaustion, etc.) We don't want to repeatedly rescue and rerun a job that
     repeatedly crashes the entire node.

  Discarding exhausted jobs may not always be desired. Use the `retry_exhausted` option if you'd
  prefer to retry exhausted jobs when they are rescued, rather than discarding them:

  ```elixir
  plugins: [{Oban.Pro.Plugins.DynamicLifeline, retry_exhausted: true}]
  ```

  During rescues, with `retry_exhausted: true`, a job's `max_attempts` is incremented and it is
  moved back to the `available` state.

  ## Instrumenting with Telemetry

  The `DynamicLifeline` plugin adds the following metadata to the `[:oban, :plugin, :stop]` event:

  * `:rescued_jobs` — a list of jobs transitioned back to `available`

  * `:discarded_jobs` — a list of jobs transitioned to `discarded`

  _Note: jobs only include `id`, `queue`, and `state` fields._
  """

  @behaviour Oban.Plugin

  use GenServer

  import Ecto.Query, only: [join: 5, select: 3, update: 3, where: 3]

  alias Oban.Pro.Engines.Smart
  alias Oban.Pro.{Facilitator, Producer}
  alias Oban.{Job, Peer, Repo, Validation}

  @type option ::
          {:conf, Oban.Config.t()}
          | {:name, Oban.name()}
          | {:retry_exhausted, boolean()}
          | {:rescue_interval, timeout()}
          | {:timeout, timeout()}

  defstruct [
    :conf,
    :rescue_timer,
    retry_exhausted: false,
    rescue_interval: :timer.minutes(1),
    timeout: :timer.seconds(30)
  ]

  defmacrop attempted_join(attempted_by, uuid) do
    quote do
      fragment(
        "array_length(?, 1) <> 1 and ? = uuid (?[2])",
        unquote(attempted_by),
        unquote(uuid),
        unquote(attempted_by)
      )
    end
  end

  defmacrop track_rescued(meta) do
    quote do
      fragment(
        """
        jsonb_set(?, '{rescued}', (COALESCE(?->>'rescued', '0')::int + 1)::text::jsonb)
        """,
        unquote(meta),
        unquote(meta)
      )
    end
  end

  @doc false
  def child_spec(args), do: super(args)

  @impl Oban.Plugin
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    case opts[:conf] do
      %{engine: Smart} ->
        GenServer.start_link(__MODULE__, struct!(__MODULE__, opts), name: name)

      %{engine: engine} ->
        raise RuntimeError, """
        DynamicLifeline requires the Smart engine to run correctly, but you're using:

        engine: #{inspect(engine)}

        You can either switch to use the Smart or remove DynamicLifeline from your plugins.
        """
    end
  end

  @impl Oban.Plugin
  def validate(opts) do
    Validation.validate_schema(opts,
      conf: :any,
      name: :any,
      rescue_interval: :pos_integer,
      rescue_after: :pos_integer,
      retry_exhausted: :boolean,
      timeout: :timeout
    )
  end

  @impl GenServer
  def init(state) do
    Process.flag(:trap_exit, true)

    :telemetry.execute([:oban, :plugin, :init], %{}, %{conf: state.conf, plugin: __MODULE__})

    {:ok, schedule_rescue(state)}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if is_reference(state.rescue_timer), do: Process.cancel_timer(state.rescue_timer)

    :ok
  end

  @impl GenServer
  def handle_info(:rescue, state) do
    if Peer.leader?(state.conf) do
      meta = %{conf: state.conf, plugin: __MODULE__}

      :telemetry.span([:oban, :plugin], meta, fn ->
        orphan_meta = rescue_orphaned(state)

        rescue_workflows(state)

        {:ok, Map.merge(meta, orphan_meta)}
      end)
    end

    {:noreply, schedule_rescue(state)}
  end

  # Scheduling

  defp schedule_rescue(state) do
    timer = Process.send_after(self(), :rescue, state.rescue_interval)

    %{state | rescue_timer: timer}
  end

  # Queries

  defp rescue_orphaned(state) do
    subquery =
      Job
      |> where([j], not is_nil(j.queue) and j.state == "executing")
      |> join(:left, [j], p in Producer, on: attempted_join(j.attempted_by, p.uuid))
      |> where([_, p], is_nil(p.uuid))

    query =
      Job
      |> join(:inner, [j], x in subquery(subquery), on: j.id == x.id)
      |> select([_, x], map(x, [:id, :meta, :queue, :state]))

    {res_count, res_jobs} = transition_available(query, state)
    {dis_count, dis_jobs} = transition_discarded(query, state)

    if state.retry_exhausted do
      %{
        discarded_count: 0,
        discarded_jobs: [],
        rescued_count: res_count + dis_count,
        rescued_jobs: res_jobs ++ dis_jobs
      }
    else
      %{
        rescued_count: res_count,
        discarded_count: dis_count,
        rescued_jobs: res_jobs,
        discarded_jobs: dis_jobs
      }
    end
  end

  defp rescue_workflows(state), do: Facilitator.rescue_workflows(state.conf)

  defp transition_available(query, state) do
    query =
      query
      |> where([j], j.attempt < j.max_attempts)
      |> update([j], set: [meta: track_rescued(j.meta), state: "available"])

    Repo.update_all(state.conf, query, [], timeout: state.timeout)
  end

  defp transition_discarded(query, %{retry_exhausted: true} = state) do
    query =
      query
      |> where([j], j.attempt >= j.max_attempts)
      |> update([j],
        inc: [max_attempts: 1],
        set: [meta: track_rescued(j.meta), state: "available"]
      )

    Repo.update_all(state.conf, query, [], timeout: state.timeout)
  end

  defp transition_discarded(query, state) do
    Repo.update_all(
      state.conf,
      where(query, [j], j.attempt >= j.max_attempts),
      [set: [state: "discarded", discarded_at: DateTime.utc_now()]],
      timeout: state.timeout
    )
  end
end
