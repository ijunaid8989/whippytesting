defmodule Oban.Pro.Migrations.DynamicPartitioner do
  @moduledoc false

  use Ecto.Migration

  alias Oban.Config
  alias Oban.Pro.Plugins.DynamicPartitioner

  def change(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")
    quoted = inspect(prefix)

    if Keyword.get(opts, :create_schema, prefix != "public") do
      execute "CREATE SCHEMA IF NOT EXISTS #{quoted}", ""
    end

    execute """
            ALTER TABLE IF EXISTS #{quoted}.oban_jobs RENAME TO oban_jobs_old
            """,
            """
            ALTER TABLE IF EXISTS #{quoted}.oban_jobs_old RENAME TO oban_jobs
            """

    execute """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_pkey RENAME TO oban_jobs_pkey_old
            """,
            """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_pkey_old RENAME TO oban_jobs_pkey
            """

    execute """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_args_index RENAME TO oban_jobs_args_index_old
            """,
            """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_args_index_old RENAME TO oban_jobs_args_index
            """

    execute """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_meta_index RENAME TO oban_jobs_meta_index_old
            """,
            """
            ALTER INDEX IF EXISTS #{quoted}.oban_jobs_meta_index_old RENAME TO oban_jobs_meta_index
            """

    execute """
            DO $$
            BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type
                           WHERE typname = 'oban_job_state'
                             AND typnamespace = '#{quoted}'::regnamespace::oid) THEN
                CREATE TYPE #{quoted}.oban_job_state AS ENUM (
                  'available',
                  'scheduled',
                  'executing',
                  'retryable',
                  'completed',
                  'discarded',
                  'cancelled'
                );
              END IF;
            END$$;
            """,
            ""

    create table(:oban_jobs,
             primary_key: false,
             prefix: prefix,
             options: "PARTITION BY LIST (state)"
           ) do
      add :id, :bigserial
      add :state, :"#{quoted}.oban_job_state", null: false, default: "available"
      add :queue, :text, null: false, default: "default"
      add :worker, :text, null: false
      add :attempt, :smallint, null: false, default: 0
      add :max_attempts, :smallint, null: false, default: 20
      add :priority, :smallint, null: false, default: 0

      add :args, :map, null: false
      add :meta, :map, null: false

      add :attempted_by, {:array, :text}
      add :errors, {:array, :map}, null: false, default: []
      add :tags, {:array, :text}, null: false, default: []

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("timezone('UTC', now())")

      add :scheduled_at, :utc_datetime_usec,
        null: false,
        default: fragment("timezone('UTC', now())")

      add :attempted_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :discarded_at, :utc_datetime_usec
    end

    create_if_not_exists index(:oban_jobs, [:id], prefix: prefix)
    create_if_not_exists index(:oban_jobs, [:args], using: :gin, prefix: prefix)
    create_if_not_exists index(:oban_jobs, [:meta], using: :gin, prefix: prefix)

    create_if_not_exists table(:oban_peers, primary_key: false, prefix: prefix) do
      add :name, :text, null: false, primary_key: true
      add :node, :text, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
    end

    execute "ALTER TABLE #{quoted}.oban_peers SET UNLOGGED", ""

    execute "COMMENT ON TABLE #{quoted}.oban_jobs IS '∞'", ""

    # Collocate available and executing to prevent concurrency anomalies such as:
    # > ERROR: tuple to be locked was already moved to another partition due to concurrent update
    execute """
            CREATE TABLE #{quoted}.oban_jobs_incomplete PARTITION OF #{quoted}.oban_jobs
            FOR VALUES IN ('available', 'executing', 'scheduled', 'retryable')
            """,
            ""

    create_if_not_exists index(
                           :oban_jobs_incomplete,
                           [:state, :queue, :priority, :scheduled_at, :id],
                           prefix: prefix
                         )

    date_partition? = fn ->
      if Code.ensure_loaded?(Mix), do: Mix.env() in ~w(dev prod)a, else: true
    end

    {part_states, date_states} =
      if Keyword.get_lazy(opts, :date_partition?, date_partition?) do
        {[], ~w(completed cancelled discarded)}
      else
        {~w(completed cancelled discarded), []}
      end

    for state <- part_states do
      execute """
              CREATE TABLE #{quoted}.oban_jobs_#{state} PARTITION OF #{quoted}.oban_jobs
              FOR VALUES IN ('#{state}')
              """,
              ""

      create_if_not_exists index("oban_jobs_#{state}", [:queue, :scheduled_at, :id],
                             prefix: prefix
                           )
    end

    for state <- date_states do
      execute """
              CREATE TABLE #{quoted}.oban_jobs_#{state} PARTITION OF #{quoted}.oban_jobs
              FOR VALUES IN ('#{state}')
              PARTITION BY RANGE (#{state}_at)
              """,
              ""

      date = Date.utc_today()
      next = Date.add(date, 1)
      safe = Calendar.strftime(date, "%Y%m%d")

      execute """
              CREATE TABLE IF NOT EXISTS #{quoted}.oban_jobs_#{state}_#{safe}
              PARTITION OF #{quoted}.oban_jobs_#{state}
              FOR VALUES FROM ('#{date} 00:00:00') TO ('#{next} 00:00:00')
              """,
              ""
    end
  end

  def up(opts \\ []), do: change(opts)

  def down(opts \\ []), do: change(opts)

  def backfill(opts \\ []) do
    if direction() == :up do
      # Ensure the oban_jobs_old table exists if this is ran in a single migration
      flush()

      DynamicPartitioner.backfill_jobs(conf(), opts)
    end
  end

  defp conf, do: Config.new(repo: repo())
end
