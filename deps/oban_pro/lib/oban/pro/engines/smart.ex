defmodule Oban.Pro.Engines.Smart do
  @moduledoc """
  The `Smart` engine provides advanced features, enhanced observability, and provides the
  foundation for accurate pruning with `Oban.Pro.Plugins.DynamicPruner` and persistence for
  `Oban.Pro.Plugins.DynamicQueues`.

  As an `Oban.Engine`, it is responsible for all non-plugin database interaction, from inserting
  through executing jobs. Major features include:

  * [Global Concurrency](#module-global-concurrency) — limits the number of concurrent jobs that
    run across _all_ nodes
  * [Rate Limiting](#module-rate-limiting) — control the number of jobs that execute within a
    window of time
  * [Queue Partitioning](#module-queue-partitioning) — segment a queue so concurrency or rate
    limits apply separately to each partition
  * [Async Tracking](#module-async-tracking) — bundle job acks (completed, cancelled, etc.) to
    minimize transactions and reduce load on the database
  * [Accurate Snooze](#module-accurate-snooze) — differentiate between attempts with errors and
    intentional snoozes
  * [Unique Bulk Inserts](#module-unique-bulk-inserts) — respect unique constraints during bulk
    inserts via `Oban.insert_all/2` with automatic batching to insert any amount of jobs without
    hitting database limits

  ## Installation

  See the [Smart Engine](adoption.md#1-smart-engine) section in the [adoption guide](adoption.md)
  to get started. The [Producer Migrations](#producer-migrations) section contains additional
  details for more complex setups with multiple instances or prefixes.

  ## Global Concurrency

  Global concurrency limits the number of concurrent jobs that run across all nodes.

  Typically the global concurrency limit is `local_limit * num_nodes`. For example, with three
  nodes and a local limit of 10, you'll have a global limit of 30. If a `global_limit` is present,
  and the `local_limit` is omitted, then the `local_limit` falls back to the `global_limit`.

  The only way to guarantee that all connected nodes will run _exactly one job_ concurrently is to
  set `global_limit: 1`.

  Here are some examples:

  ```elixir
  # Execute 10 jobs concurrently across all nodes, with up to 10 on a single node
  my_queue: [global_limit: 10]

  # Execute 10 jobs concurrently, but only 3 jobs on a single node
  my_queue: [local_limit: 3, global_limit: 10]

  # Execute at most 1 job concurrently
  my_queue: [global_limit: 1]
  ```

  ## Rate Limiting

  Rate limiting controls the number of jobs that execute within a period of time.

  Rate limiting uses counts for the same queue from all other nodes in the cluster (with or
  without Distributed Erlang). The limiter uses a sliding window over the configured period to
  accurately approximate a limit.

  Every job execution counts toward the rate limit, regardless of whether the job completes,
  errors, snoozes, etc.

  Without a modifier, the `rate_limit` period is defined in seconds. However, you can provide a
  `:second`, `:minute`, `:hour` or `:day` modifier to use more intuitive values.

  * `period: 30` — 30 seconds
  * `period: {1, :minute}` — 60 seconds
  * `period: {2, :minutes}` — 120 seconds
  * `period: {1, :hour}` — 3,600 seconds
  * `period: {1, :day}` —86,400 seconds

  Here are a few examples:

  ```elixir
  # Execute at most 1 job per second, the lowest possible limit
  my_queue: [rate_limit: [allowed: 1, period: 1]]

  # Execute at most 10 jobs per 30 seconds
  my_queue: [rate_limit: [allowed: 10, period: 30]]

  # Execute at most 10 jobs per minute
  my_queue: [rate_limit: [allowed: 10, period: {1, :minute}]]

  # Execute at most 1000 jobs per hour
  my_queue: [rate_limit: [allowed: 1000, period: {1, :hour}]]
  ```

  > #### Understanding Concurrency Limits {: .info}
  >
  > The local, global, or rate limit with the **lowest value** determines how many jobs are executed
  > concurrently. For example, with a `local_limit` of 10 and a `global_limit` of 20, a single node
  > will run 10 jobs concurrently. If that same queue had a `rate_limit` that allowed 5 jobs within
  > a period, then a single node is limited to 5 jobs.

  ## Queue Partitioning

  In addition to global and rate limits at the queue level, you can partition a queue so that it's
  treated as multiple queues where concurrency or rate limits apply separately to each partition.

  Partitions are specified with `fields` and `keys`, where `keys` is optional but _highly_
  recommended if you've included `:args`. Aside from making partitions easier to reason about,
  partitioning by keys minimizes the amount of data a queue needs to track and simplifies
  job-fetching queries.

  ### Configuring Partitions

  The partition syntax is identical for global and rate limits (note that you can partition by
  _global or rate_, but not both.)

  Here are a few examples of viable partitioning schemes:

  ```elixir
  # Partition by worker alone
  partition: :worker

  # Partition by the `id` and `account_id` from args, ignoring the worker
  partition: [args: [:id, :account_id]]

  # Partition by worker and the `account_id` key from args
  partition: [:worker, args: :account_id]
  ```

  Remember, take care to minimize partition cardinality by using a few `keys` whenever possible.
  Partitioning based on _every permutation_ of your `args` makes concurrency or rate limits hard to
  reason about and can negatively impact queue performance.

  ### Global Partitioning

  Global partitioning changes global concurency behavior. Rather than applying a fixed number for
  the queue, it applies to every partition within the queue.

  Consider the following example:

  ```elixir
  local_limit: 10, global_limit: [allowed: 1, partition: :worker]
  ```

  The queue is configured to run one job per-worker across every node, but only 10 concurrently on a
  single node. That is in contrast to the standard behaviour of `global_limit`, which would override
  the `local_limit` and only allow 1 concurrent job across every node.

  Alternatively, you could partition by a single key:

  ```elixir
  local_limit: 10, global_limit: [allowed: 1, partition: [args: :tenant_id]]
  ```

  That configures the queue to run one job concurrently across the entire cluster per `tenant_id`.

  ### Rate Limit Partitioning

  Rate limit partitions operate similarly to global partitions. Rather than limiting all jobs within
  the queue, they limit each partition within the queue.

  For example, to allow one job per-worker, every five seconds, across every instance of the `alpha`
  queue in your cluster:

  ```elixir
  local_limit: 10, rate_limit: [allowed: 1, period: 5, partition: :worker]
  ```

  ## Async Tracking

  The results of job execution, e.g. `completed`, `cancelled`, etc., are bundled together into a
  single transaction to minimize load on an app's Ecto pool and the database.

  Bundling updates and reporting them asynchronously dramatically reduces the number of
  transactions per second. However, async bundling introduces a slight lag (up to 5ms) between job
  execution finishing and recording the outcome in the database.

  Async tracking can be disabled for specific queues with the `ack_async` option:

  ```elixir
  queues: [
    standard: 30,
    critical: [ack_async: false, local_limit: 10]
  ]
  ```

  ## Accurate Snooze

  Unlike the `Basic` engine which increments `attempts` and `max_attempts`, the Smart engine rolls
  back the `attempt` on snooze. This approach preserves the original `max_attempts` and records a
  `snoozed` count in `meta`. As a result, it's simple to differentiate between "real" attempts and
  snoozes, and backoff calculation remains accurate regardless of snoozing.

  The following `process/1` function demonstrates checking a job's `meta` for a `snoozed` count:

  ```elixir
  def process(job) do
    case job.meta do
      %{"orig_scheduled_at" => unix_microseconds, "snoozed" => snoozed} ->
        IO.inspect({snoozed, unix_microseconds}, label: "Times snoozed since")

      _ ->
        # This job has never snoozed before
    end
  end
  ```

  ## Unique Bulk Inserts

  Where the `Basic` engine requires you to insert unique jobs individually, the `Smart` engine adds
  unique job support to `Oban.insert_all/2`. No additional configuration is necessary—simply use
  `insert_all` instead for unique jobs.

  ```elixir
  Oban.insert_all(lots_of_unique_jobs)
  ```

  Bulk insert also features automatic batching to support inserting an arbitrary number of jobs
  without hitting database limits (PostgreSQL's binary protocol has a limit of 65,535 parameters
  that may be sent in a single call. That presents an upper limit on the number of rows that may be
  inserted at one time.)

  ```elixir
  list_of_args
  |> Enum.map(&MyApp.MyWorker.new/1)
  |> Oban.insert_all()
  ```

  The default batch size for unique jobs is `250`, and `1_000` for non-unique jobs. Regardless, you
  can override with `batch_size`:

  ```elixir
  Oban.insert_all(lots_of_jobs, batch_size: 1500)
  ```

  It's also possible to set a custom timeout for batch inserts:

  ```elixir
  Oban.insert_all(lots_of_jobs, timeout: :infinity)
  ```

  A single batch of jobs is inserted without a transaction. Above that, each batch of jobs is
  inserted in a single transaction, _unless_ there are 10k total unique jobs to insert. After that
  threshold each batch is committed in a separate transaction to prevent memory errors. It's
  possible to control the transaction threshold with `xact_limit` if you happen to have a tuned
  database. For example, to set the limit at 20k jobs:

  ```elixir
  Oban.insert_all(lots_of_jobs, xact_limit: 20_000)
  ```

  ## Producer Migrations

  For multiple Oban instances you'll need to configure each one to use the `Smart` engine,
  otherwise they'll default to the `Basic` engine.

  If you use prefixes, or have multiple instances with different prefixes, you can specify the
  prefix and create multiple tables in one migration:

  ```elixir
  use Ecto.Migration

  def change do
  Oban.Pro.Migrations.Producers.change()
  Oban.Pro.Migrations.Producers.change(prefix: "special")
  Oban.Pro.Migrations.Producers.change(prefix: "private")
  end
  ```

  The `Producers` migration also exposes `up/0` and `down/0` functions if `change/0` doesn't fit
  your usecase.
  """

  @behaviour Oban.Engine
  @behaviour Oban.Pro.Handler

  import Ecto.Query
  import DateTime, only: [utc_now: 0]

  alias Ecto.{Changeset, Multi}
  alias Oban.{Backoff, Config, Engine, Job, Repo}
  alias Oban.Pro.Limiters.{Global, Local, Rate}
  alias Oban.Pro.{Handler, Producer, Unique, Utils}

  @type partition ::
          :worker
          | {:args, atom()}
          | [:worker | {:args, atom()}]
          | [fields: [:worker | :args], keys: [atom()]]

  @type period :: pos_integer() | {pos_integer(), unit()}

  @type global_limit :: pos_integer() | [allowed: pos_integer(), partition: partition()]

  @type local_limit :: pos_integer()

  @type rate_limit :: [allowed: pos_integer(), period: period(), partition: partition()]

  @type unit :: :second | :seconds | :minute | :minutes | :hour | :hours | :day | :days

  @ack_tabs Map.new(0..7, &{&1, :"pro_ack_tab_#{&1}"})
  @ack_tabs_size map_size(@ack_tabs)

  @registry Oban.Registry

  @smart_opts Application.compile_env(:oban_pro, __MODULE__, %{})

  @base_batch_size Map.get(@smart_opts, :base_batch_size, 1_000)
  @base_xact_limit Map.get(@smart_opts, :base_xact_limit, 10_000)
  @fetch_xact_timeout Map.get(@smart_opts, :fetch_xact_timeout, 30_000)
  @partition_limit Map.get(@smart_opts, :partition_limit, 5_000)
  @uniq_batch_size Map.get(@smart_opts, :uniq_batch_size, 250)

  defguardp is_global(producer) when is_map(producer.meta) and is_map(producer.meta.global_limit)

  defmacrop contains?(column, map) do
    quote do
      fragment("? @> ?", unquote(column), unquote(map))
    end
  end

  defmacrop contained_in?(column, map) do
    quote do
      fragment("? <@ ?", unquote(column), unquote(map))
    end
  end

  @impl Handler
  def on_start do
    for {_idx, name} <- @ack_tabs do
      :ets.new(name, [:public, :named_table, read_concurrency: true, write_concurrency: true])
    end
  end

  @impl Handler
  def on_stop, do: :ok

  @impl Engine
  def init(%Config{} = conf, [_ | _] = opts) do
    {validate?, opts} = Keyword.pop(opts, :validate, false)
    {prod_opts, meta_opts} = Keyword.split(opts, ~w(ack_async queue refresh_interval updated_at)a)

    prod_opts =
      prod_opts
      |> Keyword.put_new(:ack_async, conf.testing == :disabled)
      |> Map.new()

    changeset =
      prod_opts
      |> Map.put(:name, conf.name)
      |> Map.put(:node, conf.node)
      |> Map.put(:meta, meta_opts)
      |> Map.put_new(:queue, :default)
      |> Map.put_new(:started_at, utc_now())
      |> Map.put_new(:updated_at, utc_now())
      |> Producer.new()

    case Changeset.apply_action(changeset, :insert) do
      {:ok, producer} ->
        if validate? do
          {:ok, producer}
        else
          with_retry(producer.meta, fn ->
            {:ok, inserted} = Repo.insert(conf, changeset)

            ack_tab =
              producer.queue
              |> :erlang.phash2(@ack_tabs_size)
              |> then(&Map.fetch!(@ack_tabs, &1))

            virtual_opts =
              prod_opts
              |> Map.take(~w(ack_async refresh_interval)a)
              |> Map.put(:ack_tab, ack_tab)

            inserted = Map.merge(inserted, virtual_opts)

            put_producer(conf, inserted)

            {:ok, inserted}
          end)
        end

      {:error, changeset} ->
        {:error, Utils.to_exception(changeset)}
    end
  end

  @impl Engine
  def refresh(%Config{} = conf, %Producer{name: name, queue: queue} = producer) do
    now = utc_now()
    outdated_at = interval_multiple(now, producer, 2)
    vanished_at = interval_multiple(now, producer, 120)

    update_query =
      Producer
      |> where([p], p.uuid == ^producer.uuid)
      |> update([p], set: [updated_at: ^now])

    delete_query =
      Producer
      |> where([p], p.uuid != ^producer.uuid and p.updated_at <= ^vanished_at)
      |> or_where(
        [p],
        p.uuid != ^producer.uuid and
          p.name == ^name and
          p.queue == ^queue and
          p.updated_at <= ^outdated_at
      )

    with_retry(producer.meta, fn ->
      Repo.transaction(conf, fn ->
        Repo.update_all(conf, update_query, [])
        Repo.delete_all(conf, delete_query)
      end)

      %{producer | updated_at: now}
    end)
  end

  defp interval_multiple(now, producer, mult) do
    time = Backoff.jitter(-mult * producer.refresh_interval, mode: :inc)

    DateTime.add(now, time, :millisecond)
  end

  @impl Engine
  def shutdown(%Config{} = conf, %Producer{} = producer) do
    monitor_unregister(conf, producer)

    put_meta(conf, producer, :paused, true)
  catch
    _kind, _reason ->
      producer
      |> Producer.update_meta(:paused, true)
      |> Changeset.apply_action!(:update)
  end

  defp monitor_unregister(conf, producer) do
    parent = self()

    Task.start(fn ->
      ref = Process.monitor(parent)

      receive do
        {:DOWN, ^ref, :process, _pid, _reason} ->
          Process.demonitor(ref, [:flush])

          Registry.delete_meta(@registry, reg_key(conf, producer))
      end
    end)
  end

  @impl Engine
  def put_meta(%Config{} = conf, %Producer{} = producer, :flush, _any) do
    producer = run_acks(conf, producer)

    if is_global(producer) do
      Producer
      |> where(uuid: ^producer.uuid)
      |> then(&Repo.update_all(conf, &1, set: [meta: producer.meta, updated_at: utc_now()]))
    end

    producer
  end

  def put_meta(%Config{} = conf, %Producer{} = producer, :paused, true) do
    changeset =
      conf
      |> run_acks(producer)
      |> Producer.update_meta(:paused, true)

    conf
    |> Repo.update!(changeset)
    |> tap(&put_producer(conf, &1))
  end

  def put_meta(%Config{} = conf, %Producer{} = producer, key, value) do
    producer
    |> Producer.update_meta(key, value)
    |> then(&Repo.update!(conf, &1))
  end

  @impl Engine
  def check_meta(_conf, %Producer{} = producer, running) do
    jids = for {_, {_, exec}} <- running, do: exec.job.id

    meta =
      producer.meta
      |> Map.from_struct()
      |> flatten_windows()

    producer
    |> Map.take(~w(name node queue uuid started_at updated_at)a)
    |> Map.put(:running, jids)
    |> Map.merge(meta)
  end

  defp flatten_windows(%{rate_limit: %{windows: windows}} = meta) do
    {pacc, cacc} =
      Enum.reduce(windows, {0, 0}, fn map, {pacc, cacc} ->
        %{"prev_count" => prev, "curr_count" => curr} = map

        {pacc + prev, cacc + curr}
      end)

    put_in(meta.rate_limit.windows, [%{"curr_count" => cacc, "prev_count" => pacc}])
  end

  defp flatten_windows(meta), do: meta

  @impl Engine
  def fetch_jobs(_conf, %{meta: %{paused: true}} = prod, _running) do
    {:ok, {prod, []}}
  end

  def fetch_jobs(_conf, %{meta: %{local_limit: limit}} = prod, running)
      when map_size(running) >= limit do
    {:ok, {prod, []}}
  end

  def fetch_jobs(%Config{} = conf, %Producer{} = producer, running) do
    acks = get_acks(producer)

    multi =
      Multi.new()
      |> Multi.put(:acks, acks)
      |> Multi.put(:conf, conf)
      |> Multi.put(:running, running)
      |> Multi.put(:producer, track_acks(acks, producer))
      |> Multi.run(:mutex, &take_lock/2)
      |> Multi.run(:ack_ids, &ack_jobs/2)
      |> Multi.run(:afh_ids, &run_flush_handlers/2)
      |> Multi.run(:local_demand, &Local.check/2)
      |> Multi.run(:global_demand, &Global.check/2)
      |> Multi.run(:rate_demand, &Rate.check/2)
      |> Multi.run(:jobs, &fetch_jobs/2)
      |> Multi.run(:tracked_producer, &track_jobs(&1, &2, running))

    with_retry(producer.meta, fn ->
      case Repo.transaction(conf, multi, timeout: @fetch_xact_timeout) do
        {:ok, %{ack_ids: ack_ids, jobs: jobs, tracked_producer: producer}} ->
          del_acks(ack_ids, producer)

          {:ok, {producer, jobs}}

        {:error, :mutex, :locked, _} ->
          jittery_sleep()

          fetch_jobs(conf, producer, running)
      end
    end)
  end

  @impl Engine
  def stage_jobs(%Config{} = conf, queryable, opts) do
    limit = Keyword.fetch!(opts, :limit)

    subquery =
      queryable
      |> select([:id, :state])
      |> where([j], j.state in ~w(scheduled retryable))
      |> where([j], not is_nil(j.queue))
      |> where([j], j.scheduled_at <= ^DateTime.utc_now())
      |> limit(^limit)

    query =
      Job
      |> join(:inner, [j], x in subquery(subquery), on: j.id == x.id)
      |> where([j, _], j.state in ~w(scheduled retryable))
      |> select([j, x], %{id: j.id, queue: j.queue, state: x.state})

    {_count, staged} = Repo.update_all(conf, query, set: [state: "available"])

    {:ok, staged}
  end

  @impl Engine
  def complete_job(%Config{} = conf, %Job{} = job) do
    set = [state: "completed", completed_at: utc_now()]

    case Process.get(:oban_recorded) do
      nil -> put_ack(conf, job, set: set)
      map -> put_ack(conf, job, set: set, meta: map)
    end

    :ok
  end

  @impl Engine
  def discard_job(%Config{} = conf, %Job{} = job) do
    put_ack(conf, job,
      set: [state: "discarded", discarded_at: utc_now()],
      push: [errors: Job.format_attempt(job)]
    )

    :ok
  end

  @impl Engine
  def error_job(%Config{} = conf, %Job{} = job, seconds) do
    orig_at = Map.get(job.meta, "orig_scheduled_at", to_unix(job.scheduled_at))

    set =
      if job.attempt >= job.max_attempts do
        [state: "discarded", discarded_at: utc_now()]
      else
        [state: "retryable", scheduled_at: seconds_from_now(seconds)]
      end

    put_ack(conf, job,
      set: set,
      push: [errors: Job.format_attempt(job)],
      meta: %{orig_scheduled_at: orig_at}
    )

    :ok
  end

  @impl Engine
  def snooze_job(%Config{} = conf, %Job{} = job, seconds) do
    snoozed = Map.get(job.meta, "snoozed", 0)
    orig_at = Map.get(job.meta, "orig_scheduled_at", to_unix(job.scheduled_at))

    put_ack(conf, job,
      inc: [attempt: -1],
      set: [
        state: "scheduled",
        scheduled_at: seconds_from_now(seconds)
      ],
      meta: %{orig_scheduled_at: orig_at, snoozed: snoozed + 1}
    )

    :ok
  end

  @impl Engine
  def cancel_job(%Config{} = conf, %Job{unsaved_error: %{}} = job) do
    put_ack(conf, job,
      set: [state: "cancelled", cancelled_at: utc_now()],
      push: [errors: Job.format_attempt(job)]
    )
  end

  def cancel_job(%Config{} = conf, %Job{} = job) do
    cancel_all_jobs(conf, where(Job, id: ^job.id))

    :ok
  end

  @impl Engine
  def cancel_all_jobs(%Config{} = conf, queryable) do
    subquery = where(queryable, [j], j.state not in ["cancelled", "completed", "discarded"])

    query =
      Job
      |> join(:inner, [j], x in subquery(subquery), on: j.id == x.id)
      |> update(set: [state: "cancelled", cancelled_at: ^utc_now()])
      |> select([_, x], map(x, [:id, :args, :attempted_by, :meta, :queue, :state, :worker]))

    {:ok, %{jobs: {_count, jobs}}} =
      Multi.new()
      |> Multi.put(:conf, conf)
      |> Multi.update_all(:jobs, query, [], Repo.default_options(conf))
      |> Multi.run(:ack, &track_cancelled_jobs/2)
      |> then(&Repo.transaction(conf, &1))

    {:ok, jobs}
  end

  @impl Engine
  def insert_job(conf, changeset, opts) do
    if changeset.valid? do
      case insert_all_jobs(conf, [changeset], opts) do
        [job] ->
          {:ok, job}

        _ ->
          {:error, changeset}
      end
    else
      {:error, changeset}
    end
  end

  @impl Engine
  def insert_all_jobs(conf, changesets, opts) do
    xact_limit = Keyword.get(opts, :xact_limit, @base_xact_limit)
    batch_size = Keyword.get(opts, :batch_size, @base_batch_size)

    {base_count, uniq_count} =
      Enum.reduce(changesets, {0, 0}, fn changeset, {base, uniq} ->
        if unique?(changeset), do: {base, uniq + 1}, else: {base + 1, uniq}
      end)

    cond do
      uniq_count == 0 and base_count <= batch_size ->
        {:ok, jobs} = insert_entries(nil, %{conf: conf, changesets: changesets, opts: opts})

        jobs

      xact_limit < uniq_count ->
        inner_insert_all(conf, changesets, uniq_count, opts)

      true ->
        fun = fn -> inner_insert_all(conf, changesets, uniq_count, opts) end

        {:ok, jobs} = Repo.transaction(conf, fun, opts)

        jobs
    end
  end

  defp inner_insert_all(conf, changesets, uniq_count, opts) do
    batch_size =
      Keyword.get_lazy(opts, :batch_size, fn ->
        if uniq_count > 0, do: @uniq_batch_size, else: @base_batch_size
      end)

    changesets
    |> Enum.map(&Unique.with_uniq_meta/1)
    |> Enum.uniq_by(&get_uniq_key(&1, System.unique_integer()))
    |> Enum.chunk_every(batch_size)
    |> Enum.flat_map(fn changesets ->
      uniques = Enum.filter(changesets, &unique?/1)

      {:ok, %{all_jobs: jobs}} =
        Multi.new()
        |> Multi.put(:conf, conf)
        |> Multi.put(:opts, opts)
        |> Multi.put(:changesets, changesets)
        |> Multi.put(:uniques, uniques)
        |> Multi.run(:xact_set, &take_uniq_locks/2)
        |> Multi.run(:dupe_map, &find_uniq_dupes/2)
        |> Multi.run(:new_jobs, &insert_entries/2)
        |> Multi.run(:rep_jobs, &apply_replacements/2)
        |> Multi.run(:all_jobs, &apply_conflicts/2)
        |> then(&Repo.transaction(conf, &1, opts))

      jobs
    end)
  end

  @impl Engine
  def retry_job(%Config{} = conf, %Job{id: id}) do
    retry_all_jobs(conf, where(Job, [j], j.id == ^id))

    :ok
  end

  @impl Engine
  def retry_all_jobs(%Config{} = conf, queryable) do
    subquery =
      queryable
      |> where([j], j.state not in ["available", "executing"])
      |> where([j], not fragment("? @> ?", j.meta, ^%{on_hold: true}))

    query =
      Job
      |> join(:inner, [j], x in subquery(subquery), on: j.id == x.id)
      |> select([_, x], map(x, [:id, :queue, :state]))
      |> update([j],
        set: [
          state: "available",
          max_attempts: fragment("GREATEST(?, ? + 1)", j.max_attempts, j.attempt),
          scheduled_at: ^utc_now(),
          completed_at: nil,
          cancelled_at: nil,
          discarded_at: nil
        ]
      )

    {_, jobs} = Repo.update_all(conf, query, [])

    {:ok, jobs}
  end

  # Insert Helpers

  defp unique?(%{changes: changes}) do
    is_map_key(changes, :unique) and is_map(changes.unique)
  end

  # Producer Fetching Helpers

  defp get_producer(conf, job_or_producer) do
    case Registry.meta(@registry, reg_key(conf, job_or_producer)) do
      {:ok, producer} -> producer
      :error -> %Producer{ack_async: false}
    end
  end

  defp put_producer(conf, producer) do
    Registry.put_meta(@registry, reg_key(conf, producer), producer)
  end

  defp reg_key(%{name: name}, %{queue: queue}), do: {name, {:producer, queue}}

  # Acking Helpers

  defp put_ack(conf, job, updates) do
    producer = get_producer(conf, job)
    global_key = Global.job_to_key(job, producer)
    handle_mfa = handle_mfa(job, conf)

    ack_entry = {{:ack, producer.name, job.queue, job.id}, global_key, handle_mfa, updates}

    if producer.ack_tab, do: :ets.insert(producer.ack_tab, ack_entry)

    cond do
      Process.get(:oban_draining) ->
        Process.delete(:oban_recorded)

        acks = [ack_entry]
        jids = ack_jobs(acks, conf)
        _afh = run_flush_handlers(acks)

        if producer.ack_tab, do: del_acks(jids, producer)

      not producer.ack_async or producer.meta.paused ->
        via = Oban.Registry.via(conf.name, {:producer, producer.queue})

        GenServer.call(via, {:put_meta, :flush, true})

      true ->
        :ok
    end
  end

  defp handle_mfa(job, conf) do
    case job.meta do
      %{"on_hold" => _, "workflow_id" => workflow_id} ->
        {Oban.Pro.Facilitator, :handle, [workflow_id, conf]}

      %{"batch_id" => _, "callback" => _} ->
        :ignore

      %{"batch_id" => batch_id} ->
        {Oban.Pro.Batcher, :handle, [job, batch_id, conf]}

      _ ->
        :ignore
    end
  end

  defp any_flush_handlers?(tab) do
    match = {:_, :_, :"$1", :_}
    guard = [{:is_tuple, :"$1"}]

    :ets.select_count(tab, [{match, guard, [true]}]) > 0
  end

  defp get_acks(%{ack_tab: tab, name: name, queue: queue}) do
    :ets.select(tab, [{{{:ack, name, queue, :_}, :_, :_, :_}, [], [:"$_"]}])
  end

  defp del_acks(ids, %{ack_tab: tab, name: name, queue: queue}) do
    Enum.each(ids, &:ets.delete(tab, {:ack, name, queue, &1}))
  end

  defp run_acks(conf, producer) do
    acks = get_acks(producer)
    jids = ack_jobs(acks, conf)

    run_flush_handlers(acks)

    del_acks(jids, producer)

    track_acks(acks, producer)
  end

  defp run_flush_handlers(_repo, %{acks: acks}) do
    {:ok, run_flush_handlers(acks)}
  end

  defp run_flush_handlers(acks) do
    mfas = for {_key, _glob, mfa, _upd} <- acks, is_tuple(mfa), uniq: true, do: mfa

    Enum.each(mfas, fn {mod, fun, arg} -> apply(mod, fun, arg) end)
  end

  # Fetch Helpers

  defp take_lock(_repo, %{conf: conf, producer: producer}) do
    %{ack_tab: tab, meta: meta, queue: queue} = producer

    if is_map(meta.global_limit) or is_map(meta.rate_limit) or any_flush_handlers?(tab) do
      lock_key = :erlang.phash2([conf.prefix, queue])

      case Repo.query(conf, "SELECT pg_try_advisory_xact_lock($1)", [lock_key]) do
        {:ok, %{rows: [[true]]}} -> {:ok, true}
        _ -> {:error, :locked}
      end
    else
      {:ok, true}
    end
  end

  defp fetch_jobs(_repo, %{conf: conf, producer: producer} = changes) do
    subset_query = fetch_subquery(changes)

    query =
      Job
      |> with_cte("subset", as: ^subset_query)
      |> join(:inner, [j], x in fragment(~s("subset")), on: true)
      |> where([j, x], j.id == x.id and j.state == "available" and j.attempt < j.max_attempts)
      |> select([j, _], j)

    updates = [
      set: [state: "executing", attempted_at: utc_now(), attempted_by: [conf.node, producer.uuid]],
      inc: [attempt: 1]
    ]

    options =
      if partitioned?(changes) do
        [prepare: :unnamed]
      else
        []
      end

    {_count, jobs} = Repo.update_all(conf, query, updates, options)

    {:ok, jobs}
  end

  defp fetch_subquery(%{local_demand: local, producer: producer} = changes) do
    case changes do
      %{global_demand: nil, rate_demand: nil} ->
        fetch_subquery(producer, local)

      %{global_demand: global, rate_demand: nil} when is_integer(global) ->
        fetch_subquery(producer, min(local, global))

      %{global_demand: nil, rate_demand: rated} when is_integer(rated) ->
        fetch_subquery(producer, min(local, rated))

      %{global_demand: global, rate_demand: [_ | _] = demands} ->
        limiter = producer.meta.rate_limit

        fetch_subquery(producer, limiter, min(local, global || local), demands)

      %{global_demand: [_ | _] = demands, rate_demand: rated} ->
        limiter = producer.meta.global_limit

        fetch_subquery(producer, limiter, min(local, rated || local), demands)

      %{global_demand: global, rate_demand: rated} ->
        limit =
          rated
          |> min(local)
          |> min(global)

        fetch_subquery(producer, limit)
    end
  end

  defp fetch_subquery(producer, limit) do
    base =
      if producer.queue == "__all__" do
        where(Job, state: "available")
      else
        where(Job, state: "available", queue: ^producer.queue)
      end

    base
    |> select([:id])
    |> order_by(asc: :priority, asc: :scheduled_at, asc: :id)
    |> limit(^max(limit, 0))
    |> lock("FOR UPDATE SKIP LOCKED")
  end

  defp fetch_subquery(producer, limiter, limit, demands) do
    if Enum.all?(demands, &(elem(&1, 0) >= limit)) do
      fetch_subquery(producer, limit)
    else
      partition = limiter.partition
      partition_by = partition_by_fields(partition)
      order_by = [asc: :priority, asc: :scheduled_at, asc: :id]

      subquery =
        Job
        |> select([:id])
        |> where(state: "available", queue: ^producer.queue)
        |> order_by(^order_by)
        |> limit(@partition_limit)

      partitioned_query =
        Job
        |> join(:inner, [j], x in subquery(subquery), on: j.id == x.id)
        |> select([j], %{id: j.id, priority: j.priority, scheduled_at: j.scheduled_at})
        |> select_merge([j], %{worker: j.worker, args: j.args})
        |> select_merge([j], %{rank: over(dense_rank(), :partition)})
        |> windows([j], partition: [partition_by: ^partition_by, order_by: ^order_by])

      conditions = demands_to_conditions(demands, limiter)

      partitioned_query
      |> subquery()
      |> select([:id, :worker, :args])
      |> where(^conditions)

      partitioned_query
      |> subquery()
      |> select([:id])
      |> where(^conditions)
      |> order_by(^order_by)
      |> limit(^max(limit, 0))
    end
  end

  # Partitioning Helpers

  defp partitioned?(%{global_demand: [_ | _]}), do: true
  defp partitioned?(%{rate_demand: [_ | _]}), do: true
  defp partitioned?(_changes), do: false

  defp partition_by_fields(partition) do
    case partition do
      %{fields: [:worker]} ->
        [:worker]

      %{fields: [:args], keys: []} ->
        [:args]

      %{fields: [:args, :worker], keys: []} ->
        [:args, :worker]

      %{fields: [:args], keys: keys} ->
        for key <- keys, do: dynamic([j], fragment("?->>?", j.args, ^key))

      %{fields: [:args, :worker], keys: keys} ->
        args_keys = for key <- keys, do: dynamic([j], fragment("?->>?", j.args, ^key))

        [:worker | args_keys]
    end
  end

  defp demands_to_conditions(demands, limiter) do
    base_allowed = dynamic([i], i.rank <= ^limiter.allowed)

    untracked_condition =
      Enum.reduce(demands, base_allowed, fn {_, worker, args}, acc ->
        case limiter.partition.fields do
          [:worker] ->
            dynamic([i], i.worker != ^worker and ^acc)

          [:args] ->
            if args == %{} do
              dynamic([i], not contained_in?(i.args, ^args) and ^acc)
            else
              dynamic([i], not contains?(i.args, ^args) and ^acc)
            end

          [:args, :worker] ->
            if args == %{} do
              dynamic([i], (i.worker != ^worker or not contained_in?(i.args, ^args)) and ^acc)
            else
              dynamic([i], (i.worker != ^worker or not contains?(i.args, ^args)) and ^acc)
            end
        end
      end)

    demands
    |> Enum.reject(&(elem(&1, 0) == 0))
    |> Enum.reduce(untracked_condition, fn {allowed, worker, args}, acc ->
      case limiter.partition.fields do
        [:worker] ->
          dynamic([i], (i.rank <= ^allowed and i.worker == ^worker) or ^acc)

        [:args] ->
          if args == %{} do
            dynamic([i], (i.rank <= ^allowed and contained_in?(i.args, ^args)) or ^acc)
          else
            dynamic([i], (i.rank <= ^allowed and contains?(i.args, ^args)) or ^acc)
          end

        [:args, :worker] ->
          if args == %{} do
            dynamic(
              [i],
              (i.rank <= ^allowed and (i.worker == ^worker or contained_in?(i.args, ^args))) or
                ^acc
            )
          else
            dynamic(
              [i],
              (i.rank <= ^allowed and (i.worker == ^worker or contains?(i.args, ^args))) or ^acc
            )
          end
      end
    end)
  end

  # Tracking Helpers

  defp ack_jobs(_repo, %{acks: acks, conf: conf}) do
    {:ok, ack_jobs(acks, conf)}
  end

  defp ack_jobs(acks, conf) do
    Enum.map(acks, fn {{:ack, _name, _queue, id}, _gkey, _mfa, updates} ->
      query = where(Job, id: ^id, state: "executing")

      query =
        case Keyword.pop(updates, :meta) do
          {nil, updates} ->
            update(query, [_], ^updates)

          {meta, updates} ->
            query
            |> update([_], ^updates)
            |> update([j], set: [meta: fragment("? || ?", j.meta, ^meta)])
        end

      Repo.update_all(conf, query, [])

      id
    end)
  end

  defp track_jobs(_repo, %{conf: conf, jobs: jobs, producer: producer}, running) do
    old_jobs = for {_ref, {_pid, %{job: job}}} <- running, do: job
    all_jobs = jobs ++ old_jobs

    meta =
      producer.meta
      |> Global.track(all_jobs)
      |> Local.track(jobs)
      |> Rate.track(jobs)

    if meta == producer.meta do
      {:ok, producer}
    else
      now = utc_now()
      query = where(Producer, uuid: ^producer.uuid)

      case Repo.update_all(conf, query, set: [meta: meta, updated_at: now]) do
        {1, _} ->
          {:ok, %{producer | meta: meta, updated_at: now}}

        # In this case the producer was erroneously deleted, possibly due to a connection error,
        # downtime, or in development after waking from sleep.
        {0, _} ->
          %{producer | meta: meta, updated_at: now}
          |> Changeset.change()
          |> then(&Repo.insert(conf, &1))
      end
    end
  end

  defp track_acks(acks, producer) when is_global(producer) do
    tracked =
      acks
      |> Enum.map(&elem(&1, 1))
      |> update_tracked(producer)

    put_in(producer.meta.global_limit.tracked, tracked)
  end

  defp track_acks(_acks, producer), do: producer

  defp update_tracked(keys, producer) do
    Enum.reduce(keys, producer.meta.global_limit.tracked, fn key, acc ->
      case get_in(acc, [key, "count"]) do
        1 -> Map.delete(acc, key)
        n when is_integer(n) -> put_in(acc, [key, "count"], n - 1)
        _ -> acc
      end
    end)
  end

  defp track_cancelled_jobs(_repo, %{conf: conf, jobs: {_count, jobs}}) do
    jobs
    |> Enum.filter(&(&1.state == "executing"))
    |> Enum.group_by(& &1.attempted_by)
    |> Enum.each(fn {[_node, uuid | _], jobs} ->
      query =
        Producer
        |> where([p], p.uuid == ^uuid)
        |> where([p], fragment("?->'global_limit' \\? 'tracked'", p.meta))

      with %Producer{meta: meta} = producer <- Repo.one(conf, query) do
        tracked =
          jobs
          |> Enum.map(&Global.job_to_key(&1, producer))
          |> update_tracked(producer)

        meta = put_in(meta.global_limit.tracked, tracked)

        %{producer | meta: meta, updated_at: utc_now()}
        |> Changeset.change()
        |> then(&Repo.update(conf, &1))
      end
    end)

    {:ok, nil}
  end

  # Insert Helpers

  @uniq_lock_query """
  SELECT key FROM UNNEST($1::int[]) key WHERE NOT pg_try_advisory_xact_lock($2::int, key)
  """

  defp take_uniq_locks(_repo, %{uniques: []}), do: {:ok, MapSet.new()}
  defp take_uniq_locks(_repo, %{conf: %{testing: :manual}}), do: {:ok, MapSet.new()}

  defp take_uniq_locks(_repo, %{conf: conf, opts: opts, uniques: uniques}) do
    pref_key = :erlang.phash2(conf.prefix)

    lock_keys =
      Enum.map(uniques, fn changeset ->
        changeset |> get_uniq_key() |> :erlang.phash2()
      end)

    with {:ok, %{rows: rows}} <- Repo.query(conf, @uniq_lock_query, [lock_keys, pref_key], opts) do
      {:ok, MapSet.new(rows, &List.first/1)}
    end
  end

  defp find_uniq_dupes(_repo, %{uniques: []}), do: {:ok, MapSet.new()}

  defp find_uniq_dupes(_repo, %{conf: conf, opts: opts, uniques: uniques}) do
    empty_query = from j in Job, select: ["0", 0, "available"], where: false

    dupes_query =
      Enum.reduce(uniques, empty_query, fn changeset, acc ->
        uniq_key = get_uniq_key(changeset)
        uniq_conditions = uniq_conditions(changeset)

        query =
          Job
          |> select([j], [type(^uniq_key, :string), j.id, j.state])
          |> where(^uniq_conditions)

        union(acc, ^query)
      end)

    dupe_map =
      conf
      |> Repo.all(dupes_query, Keyword.put(opts, :prepare, :unnamed))
      |> Map.new(fn [key, id, state] -> {key, {id, state}} end)

    {:ok, dupe_map}
  end

  defp take_keys(changeset, field, keys) do
    normalized =
      changeset
      |> Changeset.get_field(field)
      |> Map.new(fn {key, val} -> {to_string(key), val} end)

    if keys == [] do
      normalized
    else
      Map.take(normalized, Enum.map(keys, &to_string/1))
    end
  end

  defp get_uniq_key(changeset, default \\ nil) do
    get_in(changeset.changes, [:meta, :uniq_key]) || default
  end

  defp uniq_conditions(%{changes: %{unique: unique}} = changeset) do
    %{fields: fields, keys: keys, period: period, states: states} = unique

    query = dynamic([j], j.state in ^Enum.map(states, &to_string/1))
    query = Enum.reduce(fields, query, &unique_field({changeset, &1, keys}, &2))

    if period == :infinity do
      query
    else
      since = DateTime.add(utc_now(), period * -1, :second)
      timestamp = Map.get(unique, :timestamp, :inserted_at)

      dynamic([j], field(j, ^timestamp) >= ^since and ^query)
    end
  end

  defp unique_field({changeset, field, keys}, acc) when field in [:args, :meta] do
    value = take_keys(changeset, field, keys)

    cond do
      value == %{} ->
        dynamic([j], contained_in?(field(j, ^field), ^value) and ^acc)

      keys == [] ->
        dynamic(
          [j],
          contains?(field(j, ^field), ^value) and contained_in?(field(j, ^field), ^value) and ^acc
        )

      true ->
        dynamic([j], contains?(field(j, ^field), ^value) and ^acc)
    end
  end

  defp unique_field({changeset, field, _}, acc) do
    value = Changeset.get_field(changeset, field)

    dynamic([j], field(j, ^field) == ^value and ^acc)
  end

  defp insert_entries(_repo, %{changesets: []}), do: {:ok, []}

  defp insert_entries(_repo, %{conf: conf, changesets: changesets, opts: opts} = changes) do
    {entries, placeholders} =
      for changeset <- changesets, not_dupe?(changeset, changes), reduce: {[], nil} do
        {entries, acc} ->
          map = Job.to_map(changeset)

          if is_nil(acc) do
            {[map | entries], map}
          else
            {[map | entries], Map.filter(acc, fn {key, val} -> map[key] == val end)}
          end
      end

    entries =
      for entry <- Enum.reverse(entries) do
        Map.new(entry, fn {key, val} ->
          if Map.has_key?(placeholders, key) do
            {key, {:placeholder, key}}
          else
            {key, val}
          end
        end)
      end

    opts = Keyword.merge(opts, on_conflict: :nothing, placeholders: placeholders, returning: true)

    {_count, jobs} = Repo.insert_all(conf, Job, entries, opts)

    {:ok, jobs}
  end

  defp not_dupe?(changeset, %{dupe_map: dupe_map, xact_set: xact_set}) do
    uniq_key = get_uniq_key(changeset)

    is_nil(uniq_key) or
      (not Map.has_key?(dupe_map, uniq_key) and
         not MapSet.member?(xact_set, uniq_key))
  end

  defp not_dupe?(_changeset, _changes), do: true

  defp apply_replacements(_repo, %{uniques: []}), do: {:ok, []}

  defp apply_replacements(_repo, %{conf: conf, dupe_map: dupe_map, opts: opts, uniques: uniques}) do
    updates =
      for %{changes: %{replace: replace} = changes} <- uniques,
          is_map_key(dupe_map, changes.meta.uniq_key),
          reduce: %{} do
        acc ->
          {job_id, job_state} = Map.get(dupe_map, changes.meta.uniq_key)

          job_state = String.to_existing_atom(job_state)
          rep_keys = Keyword.get(replace, job_state, [])

          changes
          |> Map.take(rep_keys)
          |> Enum.reduce(acc, fn {key, val}, sub_acc ->
            Map.update(sub_acc, {key, val}, [job_id], &[job_id | &1])
          end)
      end

    Enum.each(updates, fn {val, ids} ->
      conf
      |> Repo.update_all(where(Job, [j], j.id in ^ids), [set: [val]], opts)
      |> elem(0)
    end)

    {:ok, []}
  end

  defp apply_conflicts(_repo, %{new_jobs: jobs, uniques: []}), do: {:ok, jobs}

  defp apply_conflicts(_repo, %{dupe_map: dupe_map, new_jobs: [], uniques: uniques})
       when map_size(dupe_map) == 0 do
    dupes =
      Enum.map(uniques, fn changeset ->
        changeset
        |> Changeset.apply_action!(:insert)
        |> Map.replace!(:conflict?, true)
      end)

    {:ok, dupes}
  end

  defp apply_conflicts(_repo, %{dupe_map: dupe_map, new_jobs: jobs, uniques: uniques}) do
    lookup =
      Map.new(uniques, fn changeset ->
        {get_in(changeset.changes, [:meta, :uniq_key]), changeset}
      end)

    dupes =
      Enum.map(dupe_map, fn {uniq_key, {job_id, _job_state}} ->
        lookup
        |> Map.fetch!(uniq_key)
        |> Changeset.apply_action!(:insert)
        |> Map.replace!(:id, job_id)
        |> Map.replace!(:conflict?, true)
      end)

    {:ok, jobs ++ dupes}
  end

  # Time Helpers

  defp seconds_from_now(seconds), do: DateTime.add(utc_now(), seconds, :second)

  defp to_unix(datetime), do: DateTime.to_unix(datetime, :microsecond)

  # Stability

  defp jittery_sleep(base \\ 10, jitter \\ 0.5) do
    diff = base * jitter

    trunc(base - diff)..trunc(base + diff)
    |> Enum.random()
    |> Process.sleep()
  end

  defp with_retry(meta, fun, attempt \\ 0) do
    fun.()
  rescue
    error in [DBConnection.ConnectionError, Postgrex.Error] ->
      if attempt < meta.retry_attempts do
        jittery_sleep(attempt * meta.retry_backoff)

        with_retry(meta, fun, attempt + 1)
      else
        reraise error, __STACKTRACE__
      end
  end
end
