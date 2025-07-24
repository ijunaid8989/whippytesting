defmodule Oban.Pro.Plugins.DynamicCron do
  @moduledoc """
  Enhanced cron scheduling that's configurable at runtime across your entire cluster. 

  `DynamicCron` can configure cron scheduling before boot or during runtime, globally, with
  scheduling guarantees and per-entry timezone overrides. It's an ideal solution for applications
  that can't miss a cron job or must dynamically start and manage scheduled jobs at runtime.

  ## Installation

  Before running the `DynamicCron` plugin you must run a migration to add the `oban_crons` table
  to your database.

  ```bash
  mix ecto.gen.migration add_oban_crons
  ```

  Open the generated migration in your editor and add a call to the migration's `change/0`
  function:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddObanCron do
    use Ecto.Migration

    defdelegate up, to: Oban.Pro.Migrations.DynamicCron
    defdelegate down, to: Oban.Pro.Migrations.DynamicCron
  end
  ```

  As with the base Oban tables, you can optionally provide a `prefix` to "namespace" the table
  within your database. Here we specify a `"private"` prefix:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddObanCron do
    use Ecto.Migration

    def up, do: Oban.Pro.Migrations.DynamicCron.up(prefix: "private")
    def down, do: Oban.Pro.Migrations.DynamicCron.down(prefix: "private")
  end
  ```

  Run the migration to create the table:

  ```bash
  mix ecto.migrate
  ```

  Now you can use the `DynamicCron` plugin and start scheduling periodic jobs!

  ## Using and Configuring

  To begin using `DynamicCron`, add the module to your list of Oban plugins in `config.exs`:

  ```elixir
  config :my_app, Oban,
    plugins: [Oban.Pro.Plugins.DynamicCron]
    ...
  ```

  By itself, without providing a crontab or dynamically inserting cron entries, the plugin doesn't
  have anything to schedule. To get scheduling started, provide a list of `{cron, worker}` or
  `{cron, worker, options}` tuples to the plugin. The syntax is identical to Oban's built in
  `:crontab` option, which means you can copy an existing standard `:crontab` list into the
  plugin's `:crontab`.

  ```elixir
  plugins: [{
    Oban.Pro.Plugins.DynamicCron,
    crontab: [
      {"* * * * *", MyApp.MinuteJob},
      {"0 * * * *", MyApp.HourlyJob, queue: :scheduled},
      {"0 0 * * *", MyApp.DailyJob, max_attempts: 1},
      {"0 12 * * MON", MyApp.MondayWorker, tags: ["scheduled"]},
      {"@daily", MyApp.AnotherDailyWorker}
    ]
  }]
  ```

  Now, when dynamic cron initializes, it will persist those cron entries to the database and start
  scheduling them according to their CRON expression. The plugin's `crontab` format is nearly
  identical to Oban's standard crontab, with a few important enhancements we'll look at soon.

  Each of the crontab entries are persisted to the database and referenced globally, by all the
  other connected Oban instances. That allows us to insert, update, or delete cron entries at any
  time. In fact, changing the schedule or options of an entry in the crontab provided to the
  plugin will automatically update the persisted entry. To demonstrate, let's modify the
  `MinuteJob` we specified so that it runs every other minute in the `:scheduled` queue:

  ```elixir
  crontab: [
    {"*/2 * * * *", MyApp.MinuteJob, queue: :scheduled},
    ...
  ]
  ```

  Now it isn't really a "minute job" any more, and the name is no longer suitable. However, we
  didn't provide a name for the entry and it's using the module name instead. To provide more
  flexibility we can add a `:name` overrride, then we can update the worker's name as well:

  ```elixir
  crontab: [
    {"*/2 * * * *", MyApp.FrequentJob, name: "frequent", queue: :scheduled},
    ...
  ]
  ```

  All entries are referenced by name, which defaults to the worker's name and must be unique. You
  may define the same worker multiple times _as long as_ you provide a name override:

  ```elixir
  crontab: [
    {"*/3 * * * *", MyApp.BasicJob, name: "client-1", args: %{client_id: 1}},
    {"*/3 * * * *", MyApp.BasicJob, name: "client-2", args: %{client_id: 2}},
    ...
  ]
  ```

  To temporarily disable scheduling jobs you can set the `paused` flag:


  ```elixir
  crontab: [
    {"* * * * *", MyApp.BasicJob, paused: true},
    ...
  ]
  ```

  To resume the job you must supply `paused: false` (or use `update/2` to resume it manually),
  simply removing the `paused` option will have no effect.

  ```elixir
  crontab: [
    {"* * * * *", MyApp.BasicJob, paused: false},
    ...
  ]
  ```

  It is also possible to delete a persisted entry during initialization by passing the `:delete`
  option:

  ```elixir
  crontab: [
    {"* * * * *", MyApp.MinuteJob, delete: true},
    ...
  ]
  ```

  One or more entries can be deleted this way. Deleting entries is idempotent, nothing will happen
  if no matching entry can be found.

  ## Automatic Synchronization

  Synchronizing persisted entries manually requires two deploys: one to flag it with `deleted:
  true` and another to clean up the entry entirely. That extra step isn't ideal for applications
  that don't insert or delete jobs at runtime.

  To delete entries that are no longer listed in the crontab automatically set the `sync_mode`
  option to `:automatic`:


  ```elixir
  [
    sync_mode: :automatic,
    crontab: [
      {"0 * * * *", MyApp.BasicJob},
      {"0 0 * * *", MyApp.OtherJob}
    ]
  ]
  ```

  To remove unwanted entries, simply delete them from the crontab:

  ```diff
   crontab: [
     {"0 * * * *", MyApp.BasicJob},
  -  {"0 0 * * *", MyApp.OtherJob}
   ]
  ```

  With `:automatic` sync, the entry for `MyApp.OtherJob` will be deleted on the next deployment.

  ## Scheduling Guarantees

  Depending on an application's restart timing or as the result of unexpected downtime, a job's
  scheduled insert period may be missed. To compensate, enable `guaranteed` mode for the entire
  crontab or on an individual bases.

  Here's an example of enabling guaranteed insertion for the entire crontab:

  ```elixir
  [
    guaranteed: true,
    crontab: [
      {"0 * * * *", MyApp.HourlyJob},
      {"0 0 * * *", MyApp.DailyJob},
      {"0 0 1 * *", MyApp.MonthlyJob},
      {"0 0 1 */2 *", MyApp.BiMonthlyJob}
    ]
  ]
  ```

  Guaranteed mode may be enabled or disabled for individual jobs instead if it's a poor fit for
  the entire crontab:

  ```elixir
  [
    crontab: [
      {"@daily", MyApp.DailyJob, guaranteed: true}
      {"@monthly", MyApp.MonthlyJob, guaranteed: false}
    ]
  ]
  ```

  Guaranteed insertion is enforced by cron name and it's durable across option changes. Changing
  an entry's `expression` or `timezone` will clear any prior insertions and reset the guarantee.

  ## Overriding the Timezone

  Without any configuration the default timezone is `Etc/UTC`. You can override that for all cron
  entries by passing a `timezone` option to the plugin:

  ```elixir
  plugins: [{
    Oban.Pro.Plugins.DynamicCron,
    timezone: "America/Chicago",
    # ...
  ```

  You can also override the timezone for individual entries by passing it as an option to the
  `crontab` list or to `DynamicCron.insert/1`:

  ```elixir
  DynamicCron.insert([
    {"0 0 * * *", MyApp.Pinger, name: "oslo", timezone: "Europe/Oslo"},
    {"0 0 * * *", MyApp.Pinger, name: "chicago", timezone: "America/Chicago"},
    {"0 0 * * *", MyApp.Pinger, name: "zagreb", timezone: "Europe/Zagreb"}
  ])
  ```

  ## Runtime Updates

  Dynamic cron entries are persisted to the database, making it easy to manipulate them through
  typical CRUD operations. The `DynamicCron` plugin provides convenience functions to simplify
  working those operations.

  The `insert/1` function takes a list of one or more tuples with the same `{expression, worker}`
  or `{expression, worker, options}` format as the plugin's `crontab` option:

  ```elixir
  DynamicCron.insert([
    {"0 0 * * *", MyApp.GenericWorker},
    {"* * * * *", MyApp.ClientWorker, name: "client-1", args: %{client_id: 1}},
    {"* * * * *", MyApp.ClientWorker, name: "client-2", args: %{client_id: 2}},
    {"* * * * *", MyApp.ClientWorker, name: "client-3", args: %{client_id: 3}}
  ])
  ```

  Be aware that `insert/1` acts like an "upsert", making it possible to modify existing entries if
  the worker or name matches. Still, it is better to use `update/2` to make targeted updates.

  ## Isolation and Namespacing

  All `DynamicCron` functions have an alternate clause that accepts an Oban instance name as the
  first argument. This is in line with base `Oban` functions such as `Oban.insert/2`, which allow
  you to seamlessly work with multiple Oban instances and across multiple database prefixes. For
  example, you can use `all/1` to list all cron entries for the instance named `ObanPrivate`:

  ```elixir
  entries = DynamicCron.all(ObanPrivate)
  ```

  Likewise, to insert a new entry using the configuration associated with the `ObanPrivate`
  instance:

  ```elixir
  {:ok, _} = DynamicCron.insert(ObanPrivate, [{"* * * * *", PrivateWorker}])
  ```

  ## Instrumenting with Telemetry

  The `DynamicCron` plugin adds the following metadata to the `[:oban, :plugin, :stop]` event:

  * `:jobs` - a list of jobs that were inserted into the database
  """

  @behaviour Oban.Plugin

  use GenServer

  import Ecto.Query, only: [from: 2, order_by: 2, select: 3, where: 2, where: 3]

  alias Oban.Cron.Expression
  alias Oban.Plugins.Cron, as: CronPlugin
  alias Oban.Pro.Cron, as: CronEntry
  alias Oban.{Job, Peer, Repo, Validation, Worker}

  @type cron_expr :: String.t()
  @type cron_name :: String.t() | atom()
  @type cron_opt ::
          {:args, Job.args()}
          | {:expression, cron_expr()}
          | {:guaranteed, boolean()}
          | {:max_attempts, pos_integer()}
          | {:paused, boolean()}
          | {:priority, 0..9}
          | {:meta, map()}
          | {:name, cron_name()}
          | {:queue, atom() | String.t()}
          | {:tags, Job.tags()}
          | {:timezone, String.t()}
  @type cron_input :: {cron_expr(), module()} | {cron_expr(), module(), [cron_opt]}

  @type sync_mode :: :manual | :automatic

  @type option ::
          {:conf, Oban.Config.t()}
          | {:guaranteed, boolean()}
          | {:crontab, [cron_input()]}
          | {:name, Oban.name()}
          | {:sync_mode, sync_mode()}
          | {:timezone, Calendar.time_zone()}
          | {:timeout, timeout()}

  defstruct [
    :conf,
    :timer,
    crontab: [],
    guaranteed: false,
    insert_history: 360,
    rebooted: false,
    sync_mode: :manual,
    timezone: "Etc/UTC"
  ]

  defguardp is_name(name) when is_binary(name) or (is_atom(name) and not is_nil(name))

  defmacrop push_trim(insertions, datetime, length) do
    quote do
      fragment(
        """
        array_prepend(?, (?)[1:? - 1])
        """,
        unquote(datetime),
        unquote(insertions),
        unquote(length)
      )
    end
  end

  @doc false
  def child_spec(args), do: super(args)

  @impl Oban.Plugin
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} =
      opts
      |> Keyword.update(:crontab, [], &normalize_crontab/1)
      |> Keyword.delete(:timeout)
      |> Keyword.pop(:name)

    GenServer.start_link(__MODULE__, struct!(__MODULE__, opts), name: name)
  end

  @impl Oban.Plugin
  def validate(opts) do
    Validation.validate_schema(opts,
      conf: :any,
      crontab: {:custom, &validate_crontab/1},
      guaranteed: :boolean,
      insert_history: :pos_integer,
      name: :any,
      sync_mode: {:enum, [:manual, :automatic]},
      timezone: :timezone,
      timeout: :timeout
    )
  end

  @doc """
  Used to retrieve all persisted cron entries.

  The `all/0` function is provided as a convenience to inspect persisted entries.

  ## Examples

  Return a list of cron schemas with raw attributes:

      entries = DynamicCron.all()
  """
  @spec all(term()) :: [Ecto.Schema.t()]
  def all(oban_name \\ Oban) do
    oban_name
    |> Oban.config()
    |> all_entries()
  end

  @doc """
  Insert cron entries into the database to start scheduling new jobs.

  Be aware that `insert/1` acts like an "upsert", making it possible to modify existing entries if
  the worker or name matches. Still, it is better to use `update/2` to make targeted updates.

  ## Examples

  Insert a list of tuples with the same `{expression, worker}` or `{expression, worker, options}`
  format as the plugin's `crontab` option.

      DynamicCron.insert([
        {"0 0 * * *", MyApp.GenericWorker},
        {"* * * * *", MyApp.ClientWorker, name: "client-1", args: %{client_id: 1}},
        {"* * * * *", MyApp.ClientWorker, name: "client-2", args: %{client_id: 2}},
        {"* * * * *", MyApp.ClientWorker, name: "client-3", args: %{client_id: 3}}
      ])
  """
  @spec insert(term(), [cron_input()]) :: {:ok, [Ecto.Schema.t()]} | {:error, Ecto.Changeset.t()}
  def insert(oban_name \\ Oban, [_ | _] = crontab) do
    conf = Oban.config(oban_name)

    Repo.transaction(conf, fn -> insert_entries(conf, crontab) end)
  rescue
    error in [Ecto.InvalidChangesetError] ->
      {:error, error.changeset}
  end

  @doc """
  Update a single cron entry, as identified by worker or name.

  Any option available when specifying an entry in the `crontab` list or when calling `insert/2`
  can be updated—that includes the cron `expression` and the `worker`.

  ## Examples

  The following call demonstrates updating every possible option:

      {:ok, _} =
        DynamicCron.update(
          "cron-1",
          expression: "1 * * * *",
          max_attempts: 10,
          name: "special-cron",
          paused: false,
          priority: 0,
          queue: "dedicated",
          tags: ["client", "scheduled"],
          timezone: "Europe/Amsterdam",
          worker: Other.Worker,
        )

  Naturally, individual options may be updated instead. For example, set `paused: true` to pause
  an entry:

      {:ok, _} = DynamicCron.update(MyApp.ClientWorker, paused: true)

  Since `update/2` operates on a single entry at a time, it is possible to rename an entry without
  doing a `delete`/`insert` dance:

      {:ok, _} = DynamicCron.update(MyApp.ClientWorker, name: "client-worker")

  Or, update an entry with a custom entry name already set:

      {:ok, _} = DynamicCron.update("cron-1", name: "special-cron")
  """
  @spec update(term(), cron_name(), [cron_opt()]) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def update(oban_name \\ Oban, name, opts) when is_name(name) do
    oban_name
    |> Oban.config()
    |> update_entry(Worker.to_string(name), opts)
  end

  @doc """
  Delete individual entries, by worker or name.

  Use `delete/1` to remove entries at runtime, rather than hard-coding the `:delete` flag into the
  `crontab` list at compile time.

  ## Examples

  With the worker as the entry name:

      {:ok, _} = DynamicCron.delete(Worker)

  With a custom name:

      {:ok, _} = DynamicCron.delete("cron-1")
  """
  @spec delete(term(), cron_name()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t() | String.t()}
  def delete(oban_name \\ Oban, name) when is_name(name) do
    oban_name
    |> Oban.config()
    |> delete_cron(Worker.to_string(name))
  end

  @doc false
  def last_match_at(cron, timezone) do
    time =
      timezone
      |> DateTime.now!()
      |> DateTime.truncate(:second)
      |> Map.put(:second, 0)

    last_match_at(cron, time, time)
  end

  @doc false
  def last_match_at(cron, since_time, match_time) do
    if Expression.now?(cron, match_time) do
      match_time
    else
      last_match_at(cron, since_time, DateTime.add(match_time, -60))
    end
  end

  # Callbacks

  @impl GenServer
  def init(state) do
    :telemetry.execute([:oban, :plugin, :init], %{}, %{conf: state.conf, plugin: __MODULE__})

    {:ok, schedule_evaluate(state)}
  end

  @impl GenServer
  def handle_call(:evaluate, _from, state) do
    manage_entries(state)
    reload_and_insert(state)

    {:reply, :ok, %{state | rebooted: true}}
  end

  @impl GenServer
  def handle_info(:evaluate, state) do
    if Peer.leader?(state.conf) do
      manage_entries(state)
      reload_and_insert(state)

      {:noreply, schedule_evaluate(%{state | rebooted: true})}
    else
      {:noreply, schedule_evaluate(state)}
    end
  end

  # Validations

  defp normalize_crontab(crontab) do
    Enum.map(crontab, fn
      {expr, worker} -> {expr, worker, []}
      tuple -> tuple
    end)
  end

  defp validate_crontab(crontab) when is_list(crontab) do
    Validation.validate(:crontab, crontab, &validate_crontab/1)
  end

  defp validate_crontab({expression, worker, opts}) do
    with {:ok, _} <- CronPlugin.parse(expression) do
      cond do
        not Code.ensure_loaded?(worker) ->
          {:error, "#{inspect(worker)} not found or can't be loaded"}

        not function_exported?(worker, :perform, 1) ->
          {:error, "#{inspect(worker)} does not implement `perform/1` callback"}

        not Keyword.keyword?(opts) ->
          {:error, "options must be a keyword list, got: #{inspect(opts)}"}

        not valid_entry?(opts) ->
          {:error,
           "expected cron options to be one of #{inspect(CronEntry.allowed_opts())}, got: #{inspect(opts)}"}

        not valid_job?(worker, opts) ->
          {:error, "expected valid job options, got: #{inspect(opts)}"}

        true ->
          :ok
      end
    end
  end

  defp validate_crontab({expression, worker}) do
    validate_crontab({expression, worker, []})
  end

  defp validate_crontab(invalid) do
    {:error,
     "expected crontab entry to be an {expression, worker} or " <>
       "{expression, worker, options} tuple, got: #{inspect(invalid)}"}
  end

  defp valid_entry?(opts) do
    string_keys = Enum.map(CronEntry.allowed_opts(), &to_string/1)

    opts
    |> Keyword.drop(~w(delete guaranteed insertions name paused)a)
    |> Enum.all?(fn {key, _} -> to_string(key) in string_keys end)
  end

  defp valid_job?(worker, opts) do
    args = Keyword.get(opts, :args, %{})
    opts = Keyword.drop(opts, ~w(args delete guaranteed insertions name paused timezone)a)

    worker.new(args, opts).valid?
  end

  # Scheduling

  defp schedule_evaluate(state) do
    timer = Process.send_after(self(), :evaluate, CronPlugin.interval_to_next_minute())

    %{state | timer: timer}
  end

  # Updating

  defp reload_and_insert(state) do
    meta = %{conf: state.conf, plugin: __MODULE__}

    :telemetry.span([:oban, :plugin], meta, fn ->
      {:ok, jobs} =
        state
        |> reload_entries()
        |> insert_scheduled_jobs(state)

      {:ok, Map.put(meta, :jobs, jobs)}
    end)
  end

  defp reload_entries(state) do
    query =
      CronEntry
      |> where(paused: false)
      |> order_by(asc: :inserted_at)
      |> select([c], %{
        c
        | insertions: type(fragment("?[1:2]", c.insertions), {:array, :utc_datetime_usec})
      })

    state.conf
    |> Repo.all(query)
    |> Enum.reduce([], fn entry, acc ->
      with {:ok, parsed} <- Expression.parse(entry.expression),
           {:ok, worker} <- Worker.from_string(entry.worker) do
        opts = Keyword.new(entry.opts, fn {key, val} -> {String.to_existing_atom(key), val} end)

        [%{entry | opts: opts, parsed: parsed, worker: worker} | acc]
      else
        _ -> acc
      end
    end)
  end

  # Inserting

  defp insert_scheduled_jobs(entries, state) do
    entries = Enum.filter(entries, &(now?(&1, state) or missed?(&1, state)))

    jobs =
      Enum.map(entries, fn entry ->
        {args, opts} = Keyword.pop(entry.opts, :args, %{})

        meta = %{cron: true, cron_expr: entry.expression, cron_name: entry.name}

        opts =
          entry.worker.__opts__()
          |> Worker.merge_opts(opts)
          |> Keyword.drop([:guaranteed, :timezone])
          |> Keyword.update(:meta, meta, &Map.merge(&1, meta))

        entry.worker.new(args, opts)
      end)

    Repo.transaction(state.conf, fn ->
      now = DateTime.utc_now()

      # Using `from` to avoid a conflict with the local update/3
      query =
        from c in CronEntry,
          where: c.name in ^Enum.map(entries, & &1.name),
          update: [set: [insertions: push_trim(c.insertions, ^now, ^state.insert_history)]]

      Repo.update_all(state.conf, query, [])
      Oban.insert_all(state.conf.name, jobs)
    end)
  end

  defp now?(%{parsed: %{reboot?: true}}, %{rebooted: true}), do: false

  defp now?(entry, state) do
    datetime =
      entry.opts
      |> Keyword.get(:timezone, state.timezone)
      |> DateTime.now!()

    Expression.now?(entry.parsed, datetime)
  end

  defp missed?(entry, state) do
    guaranteed? = Keyword.get(entry.opts, :guaranteed, state.guaranteed)

    cond do
      [] == entry.insertions ->
        false

      not guaranteed? ->
        false

      entry.parsed.reboot? ->
        false

      true ->
        timezone = Keyword.get(entry.opts, :timezone, state.timezone)

        last_inserted_at =
          entry.insertions
          |> List.first()
          |> DateTime.shift_zone!(timezone)

        entry.parsed
        |> last_match_at(timezone)
        |> DateTime.compare(last_inserted_at)
        |> Kernel.==(:gt)
    end
  end

  # Entry Management

  defp manage_entries(%{rebooted: true}), do: :ok

  defp manage_entries(%{sync_mode: :automatic} = state) do
    Repo.transaction(state.conf, fn ->
      delete_missing(state.conf, state.crontab)
      insert_entries(state.conf, state.crontab)
    end)
  end

  defp manage_entries(state) do
    Repo.transaction(state.conf, fn ->
      {deletes, inserts} =
        Enum.split_with(state.crontab, fn {_expr, _work, opts} ->
          Keyword.get(opts, :delete)
        end)

      delete_entries(state.conf, deletes)
      insert_entries(state.conf, inserts)
    end)
  end

  defp insert_entries(conf, crontab) do
    Enum.map(crontab, fn tuple ->
      changeset = CronEntry.changeset(tuple)

      replace =
        for {key, val} <- changeset.changes,
            key in ~w(expression worker opts paused)a,
            val != %{},
            do: key

      repo_opts = [conflict_target: :name, on_conflict: {:replace, replace}]

      Repo.insert!(conf, changeset, repo_opts)
    end)
  end

  defp delete_entries(conf, crontab) do
    Repo.delete_all(conf, where(CronEntry, [e], e.name in ^crontab_names(crontab)))
  end

  defp delete_missing(conf, crontab) do
    Repo.delete_all(conf, where(CronEntry, [e], e.name not in ^crontab_names(crontab)))
  end

  defp crontab_names(crontab) do
    Enum.map(crontab, fn {_expr, worker, opts} ->
      opts
      |> Keyword.get(:name, worker)
      |> Worker.to_string()
    end)
  end

  # Queries

  defp all_entries(conf) do
    Repo.all(conf, order_by(CronEntry, asc: :inserted_at))
  end

  defp update_entry(conf, name, params) do
    with {:ok, entry} <- fetch_entry(conf, name) do
      changeset = CronEntry.update_changeset(entry, Map.new(params))

      Repo.update(conf, changeset)
    end
  end

  defp delete_cron(conf, name) do
    with {:ok, entry} <- fetch_entry(conf, name), do: Repo.delete(conf, entry)
  end

  defp fetch_entry(conf, name) do
    case Repo.one(conf, where(CronEntry, name: ^name)) do
      nil -> {:error, "no cron entry named #{inspect(name)} could be found"}
      entry -> {:ok, entry}
    end
  end
end
