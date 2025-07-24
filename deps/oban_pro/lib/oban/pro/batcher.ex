defmodule Oban.Pro.Batcher do
  @moduledoc false

  @behaviour Oban.Pro.Handler

  import Ecto.Query, only: [limit: 2, select: 3, union_all: 2, where: 3]

  alias Oban.Pro.Engines.Smart
  alias Oban.{Job, Repo, Worker}

  require Logger

  @callbacks_to_functions %{
    "attempted" => :handle_attempted,
    "cancelled" => :handle_cancelled,
    "completed" => :handle_completed,
    "discarded" => :handle_discarded,
    "exhausted" => :handle_exhausted,
    "retryable" => :handle_retryable
  }

  @callbacks_to_states %{
    "attempted" => ~w(scheduled available executing),
    "completed" => ~w(scheduled available executing retryable cancelled discarded),
    "cancelled" => ~w(cancelled),
    "discarded" => ~w(discarded),
    "exhausted" => ~w(scheduled retryable available executing),
    "retryable" => ~w(retryable)
  }

  @all_states Enum.map(Job.states(), &to_string/1)

  @impl Oban.Pro.Handler
  def on_start do
    events = [
      [:oban, :engine, :cancel_all_jobs, :stop]
    ]

    :telemetry.attach_many("oban.batch", events, &__MODULE__.handle_event/4, nil)
  end

  @impl Oban.Pro.Handler
  def on_stop do
    :telemetry.detach("oban.batch")
  end

  def handle_event(_event, _timing, %{conf: conf, jobs: jobs}, _) do
    for %{meta: %{"batch_id" => batch_id}} = job <- jobs do
      handle(job, batch_id, conf)
    end
  end

  # Constants

  def callbacks_to_functions, do: @callbacks_to_functions

  # Handling

  def handle(job, batch_id, conf) do
    batch_worker = Map.get(job.meta, "batch_callback_worker", job.worker)

    with {:ok, worker} <- Worker.from_string(batch_worker),
         supported = supported_callbacks(worker),
         {:ok, {states, exists}} <- states_for_callbacks(supported, batch_id, conf) do
      for callback <- supported,
          callback not in exists,
          callback_ready?(callback, states) do
        insert_callback(callback, batch_id, worker, job, conf)
      end
    end
  end

  defp supported_callbacks(worker) do
    for {name, func} <- @callbacks_to_functions,
        function_exported?(worker, func, 1),
        do: name
  end

  defp states_for_callbacks([], _batch_id, _conf), do: :ok

  defp states_for_callbacks(callbacks, batch_id, conf) do
    state_query =
      callbacks
      |> Enum.flat_map(&Map.fetch!(@callbacks_to_states, &1))
      |> Enum.uniq()
      |> Enum.reduce(:none, fn state, acc ->
        query =
          Job
          |> select([_], [type(^state, :string)])
          |> where([j], fragment("? \\? 'batch_id'", j.meta))
          |> where([j], fragment("? ->> 'batch_id'", j.meta) == ^batch_id)
          |> where([j], is_nil(fragment("? ->> 'callback'", j.meta)))
          |> where([j], j.state == ^state)
          |> limit(1)

        if acc == :none, do: query, else: union_all(acc, ^query)
      end)

    exist_query =
      Enum.reduce(callbacks, :none, fn callback, acc ->
        query =
          Job
          |> select([_j], [type(^callback, :string)])
          |> where([j], fragment("? \\? 'batch_id'", j.meta))
          |> where([j], fragment("? ->> 'batch_id'", j.meta) == ^batch_id)
          |> where([j], fragment("? ->> 'callback'", j.meta) == ^callback)
          |> where([j], j.state in @all_states)

        if acc == :none, do: query, else: union_all(acc, ^query)
      end)

    Repo.transaction(conf, fn ->
      states = conf |> Repo.all(state_query) |> List.flatten()
      exists = conf |> Repo.all(exist_query) |> List.flatten()

      {states, exists}
    end)
  end

  defp callback_ready?(callback, batch_states) do
    ready? =
      @callbacks_to_states
      |> Map.fetch!(callback)
      |> Enum.any?(&(&1 in batch_states))

    # Other callbacks use a negated query to avoid counting `completed` jobs.
    if callback in ~w(cancelled discarded retryable) do
      ready?
    else
      not ready?
    end
  end

  defp insert_callback(callback, batch_id, worker, job, conf) do
    batch_args = Map.get(job.meta, "batch_callback_args", %{})
    batch_meta = Map.get(job.meta, "batch_callback_meta", %{})
    batch_queue = Map.get(job.meta, "batch_callback_queue", job.queue)

    meta = Map.merge(batch_meta, %{callback: callback, batch_id: batch_id})

    unique = [
      period: :infinity,
      fields: [:worker, :queue, :meta],
      keys: [:batch_id, :callback],
      states: Job.states()
    ]

    changeset = worker.new(batch_args, meta: meta, queue: batch_queue, unique: unique)

    if not changeset.valid? and Keyword.has_key?(changeset.errors, :args) do
      changeset
      |> structured_error_message()
      |> Logger.error()
    else
      {:ok, Smart.insert_job(conf, changeset, [])}
    end
  end

  defp structured_error_message(changeset) do
    """
    [Oban.Pro.Workers.Batch] can't insert batch callback because it has invalid keys:

      #{get_in(changeset.errors, [:args, Access.elem(0)])}

    Use one of the following options to restore batch callbacks:

    * Modify structured `keys` or `required` to allow the missing keys
    * Include the required arguments with the `batch_callback_args` option
    * Specify a different callback worker with the `batch_callback_worker` option
    """
  end
end
