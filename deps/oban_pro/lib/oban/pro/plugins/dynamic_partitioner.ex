defmodule Oban.Pro.Plugins.DynamicPartitioner do
  @moduledoc """
  The `DynamicPartitioner` plugin manages a partitioned `oban_jobs` table for optimized query
  performance, minimal database bloat, and efficiently pruned historic jobs. Partitioning can
  minimize database bloat for tables of any size, but it's ideally suited for high throughput
  applications that run millions of jobs a week.

  Partitioning is only officially supported on Postgres 11 and higher. While older versions of
  Postgres support partitioning, they have prohibitive technical limitations and your experience
  may vary.

  ## Installation

  Before running the `DynamicPartitioner` plugin, you must run a migration to create a partitioned
  `oban_jobs` table to your database.

  > #### Table Name Conflicts {: .info}
  >
  > Existing `oban_jobs` tables can't be converted to a partitioned table in place and require a
  > transition stage. The migration will automatically handle table conflicts by renaming the
  > existing table to `oban_jobs_old`. However, if the partitioned table is added to a different
  > prefix without a conflict, then the original table is left untouched and both tables are named
  > `oban_jobs`.
  >
  > See the [Backfilling and Migrating](##module-backfilling-and-migrating) section for strategies
  > before running migrations.

  ```bash
  mix ecto.gen.migration add_partitioned_oban_jobs
  ```

  Open the generated migration in your editor and delegate to the dynamic partitions migration:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddPartitionedObanJobs do
    use Ecto.Migration

    defdelegate change, to: Oban.Pro.Migrations.DynamicPartitioner
  end
  ```

  As with the standard `oban_jobs` table, you can optionally provide a `prefix` to "namespace" the table
  within your database. Here we specify a `"partitioned"` prefix:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddPartitionedObanJobs do
    use Ecto.Migration

    def change do
      Oban.Pro.Migrations.DynamicPartitioner.change(prefix: "partitioned")
    end
  end
  ```

  Run the migration to create the new table:

  ```bash
  mix ecto.migrate
  ```

  The new table is partitioned for optimal inserts, ready for you to backfill any existing jobs
  and configure retention periods.

  ### Date Partitioning in Test Environments

  To prevent testing errors after migration, the `completed`, `cancelled`, and `discarded` states
  are sub-partitioned by date only in `:dev` and `:prod` environments.

  You can explicitly enable date partitioning in other production-like environments with the
  `date_partition?` flag:

  ```elixir
  Oban.Pro.Migrations.DynamicPartitioner.change(date_partition?: true)
  ```

  ## Backfilling and Migrating

  Below are several recommended strategies for backfilling original jobs into the new partitioned
  table. They're listed in order of complexity, beginning with the least invasive approach.

  ### Strategy 1: Don't Backfill at All

  The most performant strategy is to not backfill jobs at all. It's perfectly acceptable to leave
  old jobs untouched if you **don't need them for uniqueness checks** or other observability
  concerns. Though, in an active system, you'll still want to finish processing jobs in the
  original table.

  During the transition period, until all of the original jobs are processed, you'll run two
  separate, entirely isolated, Oban instances:

  1. **Original** — configured with the original prefix, `public` if you never changed it. This
     instance will run all of the original queues, without any plugins and it won't insert new
     jobs.

  2. **Partitioned** — configured with the new prefix for the partitioned table, all of your
     original queues, plugins, and any other options.

  Here's an example of that configuration:

  ```elixir
  queues = [
    default: 10,
    other_queue: 10,
    and_another: 10
  ]

  config :my_app, Oban.Original, queues: queues

  config :my_app, Oban,
    prefix: "partitioned",
    queues: queues,
    plugins: [
      ...
  ```

  Now, start both Oban instances within your application's supervisor:

  ```diff
   children = [
     MyApp.Repo,
     {Oban, Application.fetch_env!(:my_app, Oban)},
  +  {Oban, Application.fetch_env!(:my_app, Oban.Original)},
     ...
   ]
  ```

  New jobs will be inserted into the `partitioned` table while existing jobs keep processing
  through the `Oban.Original` instance. Once the all original jobs have executed you're free to
  remove the extra instance and [drop the original table](#module-cleaning-up).

  ### Strategy 2: Backfill Old Jobs

  This strategy moves old jobs automatically as part of a migration. The `backfill/1` migration
  helper, which delegates to `backfill_jobs/2`, helps move jobs in batches for each state.

  By default, backfilling includes _all states_ and is intended for smaller tables, i.e. 50k-100k
  total jobs.

  Backfill by creating an additional migration with ddl transaction disabled:

  ```elixir
  defmodule MyApp.Repo.Migrations.BackfillPartitionedObanJobs do
    use Ecto.Migration

    @disable_ddl_transaction true

    def change do
      Oban.Pro.Migrations.DynamicPartitioner.backfill()
    end
  end
  ```

  Like all other migrations, `backfill/1` accepts options to control the table's prefix. You can
  specify both old and new prefixes to handle situations where the partitioned table lives in a
  different prefix:

  ```elixir
  def change do
    Oban.Pro.Migrations.DynamicPartitioner.backfill(new_prefix: "private", old_prefix: "public")
  end
  ```

  For larger tables, or applications that are sensitive to longer migrations, you can split
  backfilling between migrations and prioritize in-flight jobs.

  Use the `states` option to restrict backfilling to actively `executing` jobs:

  ```elixir
  def change do
    Oban.Pro.Migrations.DynamicPartitioner.backfill(states: ~w(executing))
  end
  ```

  For the remaining jobs, you can either use a secondary migration or manually call
  `backfill_jobs/1` from your application code.

  See `backfill_jobs/1` for the full range of backfill options including changing the batch size
  and automatically sleeping between batches.

  ### Cleaning Up

  After backfilling is complete you can drop the original `oban_jobs` table. Be _very_ careful to
  ensure you're dropping the old job table! If the new and old prefix was the same, which it is by
  default, then the table has `_old` appended.

  ```elixir
  defmodule MyApp.Repo.Migrations.DropStandardObanJobs do
    use Ecto.Migration

    def change do
      drop_if_exists table(:oban_jobs_old)
    end
  end
  ```

  ## Using and Configuring

  After running the migration to partition tables, enable the plugin to manage sub-partitions:

  ```elixir
  config :my_app, Oban,
    plugins: [Oban.Pro.Plugins.DynamicPartitioner]
    ...
  ```

  The plugin will preemptively create sub-partitions for finished job states (`completed`,
  `cancelled`, `discarded`) as well as prune partitions older than the retention period. By
  default, older jobs are retained for 3 days.

  You can override the retention period for states individually. For example, to retain `completed`
  jobs for 2 days, `cancelled` for 7, and `discarded` for 30:

  ```elixir
  plugins: [{
    Oban.Pro.Plugins.DynamicPartitioner,
    retention: [completed: 2, cancelled: 7, discarded: 30]
  }]
  ```

  Pruning sub-partitions is an extremely fast operation akin to dropping a table. As a result,
  there is zero lingering bloat. It's not advised that you use the `DynamicPruner`, unless
  you're pruning a subset jobs aggressively after a few minutes, hours, etc.

  ```diff
  plugins: [
    Oban.Pro.Plugins.DynamicPartitioner,
  - Oban.Plugins.Pruner,
  - Oban.Pro.Plugins.DynamicPruner
  ]
  ```

  `DynamicPartitioner` will warn you if the standard `Pruner` is enabled at the same time.

  ### Tuning Partition Management

  The partitioner attempts once an hour to pre-create partitions two days in advance. That
  schedule and buffer should be suitable for most applications. However, you can increase the
  buffer period and set an alternate schedule if necessary.

  For example, to increase the buffer to 3 days and run at 05:00 in the Europe/Paris timezone:

  ```elixir
  plugins: [{
    Oban.Pro.Plugins.DynamicPartitioner,
    buffer: 3,
    schedule: "0 5 * * *",
    timezone: "Europe/Paris"
  }]
  ```

  ## Instrumenting with Telemetry

  The `DynamicPartitioner` plugin doesn't add any metadata to the `[:oban, :plugin, :stop]` event.
  """

  @behaviour Oban.Plugin

  use GenServer

  alias __MODULE__, as: State
  alias Oban.Cron.Expression
  alias Oban.Plugins.{Cron, Pruner}
  alias Oban.{Config, Peer, Repo, Validation}

  require Logger

  @type retention :: [
          completed: pos_integer(),
          cancelled: pos_integer(),
          discarded: pos_integer()
        ]

  @type option ::
          {:conf, Oban.Config.t()}
          | {:name, GenServer.name()}
          | {:retention, retention()}
          | {:schedule, String.t()}
          | {:timeout, timeout()}
          | {:timezone, String.t()}

  @retention [completed: 3, cancelled: 3, discarded: 3]
  @states Keyword.keys(@retention)

  defstruct [
    :conf,
    :name,
    :retention,
    :schedule,
    :timer,
    buffer: 2,
    timeout: :timer.minutes(1),
    timezone: "Etc/UTC"
  ]

  @doc false
  def child_spec(args), do: super(args)

  @impl Oban.Plugin
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl Oban.Plugin
  def validate(opts) do
    Validation.validate_schema(opts,
      buffer: :pos_integer,
      conf: {:custom, &validate_conf/1},
      name: :any,
      retention: {:custom, &validate_retention/1},
      schedule: :schedule,
      timeout: :timeout,
      timezone: :timezone
    )
  end

  @sub_states ~w(cancelled completed discarded)

  @defaults [
    new_prefix: "public",
    old_prefix: "public",
    states: ~w(executing available retryable scheduled cancelled discarded completed),
    batch_size: 5_000,
    batch_sleep: 0
  ]

  @doc false
  def backfill_jobs, do: backfill_jobs(Oban, [])

  @doc """
  Backfill jobs from a standard table into a newly partitioned table.

  Backfilling is flexible enough to run against one or more job states, with arbitrary batch
  sizes, and without transactional blocks. That allows repeated backfill runs in the face of
  restarts or database errors.

  Sub-partitions by date are created for final states (`completed`, `cancelled`, `discarded`)
  automatically before jobs are moved.

  ## Options

  * `:new_prefix` — The prefix where the new partitioned `oban_jobs` table resides. Defaults to
    `public`.

  * `:old_prefix` — The prefix where the standard `oban_jobs_old` table resides. Defaults to
    `public`.

  * `:batch_size` — The number of jobs to move (delete/insert) in a single query. Defaults to a
    conservative 5,000 jobs per batch.

  * `:batch_sleep` — The amount of time to sleep between backfill batches in order to minimize
    load on the database. Defaults to 0, no downtime between batches.

  * `:states` — A list of job states to backfill jobs from. Defaults to all states.

  ## Examples

  Backfill old jobs across all states in the default `public` prefix:

      DynamicPartitioner.backfill_jobs()

  Restrict backfilling to incomplete job states:

      DynamicPartitioner.backfill_jobs(states: ~w(executing available scheduled retryable))

  Backfill to and from an alternate prefix:

      DynamicPartitioner.backfill_jobs(old_prefix: "private", new_prefix: "private")

  Backfill using larger batches with half a second between queries:

      DynamicPartitioner.backfill_jobs(batch_size: 20_000, batch_sleep: 500)
  """
  @spec backfill_jobs(name_or_conf :: Oban.name() | Config.t(), opts :: Keyword.t()) :: :ok
  def backfill_jobs(conf_or_name, opts \\ [])

  def backfill_jobs(%Config{} = conf, opts) when is_list(opts) do
    opts =
      opts
      |> Keyword.validate!(@defaults)
      |> Keyword.update!(:states, fn states -> Enum.map(states, &to_string/1) end)
      |> Map.new()

    old_table =
      if opts.old_prefix == opts.new_prefix do
        "oban_jobs_old"
      else
        "oban_jobs"
      end

    conf = %Config{conf | prefix: opts.new_prefix}
    opts = Map.put(opts, :old_table, old_table)

    for state <- opts.states do
      backfill_partitions(conf, state, opts)
      backfill_jobs(conf, state, opts)
    end

    :ok
  end

  def backfill_jobs(oban_name, opts) do
    oban_name
    |> Oban.config()
    |> backfill_jobs(opts)
  end

  defp backfill_partitions(conf, state, opts) when state in @sub_states do
    query = """
    SELECT DISTINCT date_trunc('day', #{state}_at)::date
    FROM #{opts.old_prefix}.#{opts.old_table}
    WHERE state = '#{state}'
    """

    {:ok, %{rows: rows}} = Repo.query(conf, query)

    rows
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&create_sub_partition(conf, state, &1))
  end

  defp backfill_partitions(_conf, _state, _opts), do: :ok

  defp backfill_jobs(conf, state, opts) do
    query = """
    WITH old_jobs AS (
      DELETE FROM #{opts.old_prefix}.#{opts.old_table}
      WHERE id IN (
        SELECT id
        FROM #{opts.old_prefix}.#{opts.old_table}
        WHERE state = '#{state}'
        LIMIT #{opts.batch_size}
      )
      RETURNING *
    ), new_jobs AS (
      INSERT INTO #{opts.new_prefix}.oban_jobs (
        id,
        state,
        queue,
        worker,
        attempt,
        max_attempts,
        priority,
        args,
        meta,
        attempted_by,
        errors,
        tags,
        inserted_at,
        scheduled_at,
        attempted_at,
        cancelled_at,
        completed_at,
        discarded_at
      ) SELECT
          id,
          state,
          queue,
          worker,
          attempt,
          max_attempts,
          priority,
          args,
          meta,
          attempted_by,
          errors,
          tags,
          inserted_at,
          scheduled_at,
          attempted_at,
          cancelled_at,
          completed_at,
          discarded_at
        FROM old_jobs
        RETURNING 1
    )

    SELECT count(*) from new_jobs
    """

    {:ok, %{rows: [[count]]}} = Repo.query(conf, query)

    if count > 0 do
      Process.sleep(opts.batch_sleep)

      backfill_jobs(conf, state, opts)
    end
  end

  @impl GenServer
  def init(opts) do
    opts =
      opts
      |> Keyword.update(:retention, @retention, &Keyword.merge(@retention, &1))
      |> Keyword.update(:schedule, Expression.parse!("@hourly"), &Expression.parse!/1)

    state =
      State
      |> struct!(opts)
      |> schedule_manage()

    :telemetry.execute([:oban, :plugin, :init], %{}, %{conf: state.conf, plugin: __MODULE__})

    {:ok, state, {:continue, :start}}
  end

  @impl GenServer
  def handle_continue(:start, state) do
    manage_tables(state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:manage, state) do
    datetime = DateTime.now!(state.timezone)

    if Peer.leader?(state.conf) and Expression.now?(state.schedule, datetime) do
      manage_tables(state)
    end

    {:noreply, schedule_manage(state)}
  end

  defp manage_tables(state) do
    meta = %{conf: state.conf, plugin: __MODULE__}

    :telemetry.span([:oban, :plugin], meta, fn ->
      Repo.transaction(state.conf, fn -> create_sub_partitions(state) end, timeout: state.timeout)
      Repo.transaction(state.conf, fn -> delete_sub_partitions(state) end, timeout: state.timeout)

      {:ok, meta}
    end)
  catch
    kind, value ->
      Logger.error(fn ->
        "[#{__MODULE__}] management error: " <> Exception.format(kind, value, __STACKTRACE__)
      end)
  end

  defp create_sub_partitions(%{buffer: buffer, conf: conf}) do
    for state <- @states, days <- 0..buffer do
      date = Date.add(Date.utc_today(), days)

      create_sub_partition(conf, state, date)
    end
  end

  defp create_sub_partition(conf, state, date) do
    quoted = inspect(conf.prefix)
    next = Date.add(date, 1)
    safe = Calendar.strftime(date, "%Y%m%d")

    command = """
    CREATE TABLE IF NOT EXISTS #{quoted}.oban_jobs_#{state}_#{safe}
      PARTITION OF #{quoted}.oban_jobs_#{state}
      FOR VALUES FROM ('#{date} 00:00:00') TO ('#{next} 00:00:00')
    """

    query!(conf, command)
  end

  defp delete_sub_partitions(%{conf: conf, retention: retention}) do
    rules =
      Map.new(retention, fn {state, days} ->
        stamp =
          Date.utc_today()
          |> Date.add(-days)
          |> Calendar.strftime("%Y%m%d")
          |> String.to_integer()

        {to_string(state), stamp}
      end)

    query = """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = '#{conf.prefix}'
    AND table_name ~ 'oban_jobs_(cancelled|completed|discarded)_.+'
    """

    for [table] <- query!(conf, query),
        <<"oban_jobs_", state::binary-size(9), "_", date::binary-size(8)>> = table,
        String.to_integer(date) <= Map.fetch!(rules, state) do
      query!(conf, "DROP TABLE IF EXISTS #{inspect(conf.prefix)}.#{table}")
    end
  end

  defp query!(conf, command) do
    case Repo.query(conf, command) do
      {:ok, %{rows: rows}} -> rows
      {:error, error} -> raise(error)
    end
  end

  # Scheduling

  defp schedule_manage(state) do
    timer = Process.send_after(self(), :manage, Cron.interval_to_next_minute())

    %{state | timer: timer}
  end

  # Validation

  defp validate_conf(conf) do
    cond do
      conf.engine != Oban.Pro.Engines.Smart ->
        {:error, "requires the Smart engine to run, got: #{inspect(conf.engine)}"}

      Keyword.has_key?(conf.plugins, Pruner) ->
        {:error, "pruning isn't compatibile with partitioning, found: #{Pruner}"}

      true ->
        :ok
    end
  end

  defp validate_retention(retention) do
    keys = Keyword.keys(retention)
    vals = Keyword.values(retention)

    cond do
      not Keyword.keyword?(retention) ->
        {:error, "expected :retention to be a keyword list, got: #{inspect(retention)}"}

      Enum.any?(keys, &(&1 not in @states)) ->
        {:error, "expected :retention keys to overlap #{inspect(@states)}, got: #{inspect(keys)}"}

      Enum.any?(vals, &((is_integer(&1) and &1 <= 0) or not is_integer(&1))) ->
        {:error, "expected :retention values to be positive integers, got: #{inspect(vals)}"}

      true ->
        :ok
    end
  end
end
