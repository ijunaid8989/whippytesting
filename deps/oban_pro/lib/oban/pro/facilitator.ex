defmodule Oban.Pro.Facilitator do
  @moduledoc false

  @behaviour Oban.Pro.Handler

  import Ecto.Query

  alias Oban.{Job, Repo}

  require Logger

  @all_states Enum.map(Job.states(), &to_string/1)
  @fin_states ~w(cancelled completed discarded)
  @incomplete_set MapSet.new(~w(available executing retryable scheduled))

  defmacrop drop_hold(meta) do
    quote do
      fragment(~s(? || '{"on_hold":false}'), unquote(meta))
    end
  end

  defmacrop name_in_deps(meta, parent_meta) do
    quote do
      fragment(
        "?->>'name' = ANY(ARRAY(SELECT jsonb_array_elements_text(?->'deps')))",
        unquote(meta),
        unquote(parent_meta)
      )
    end
  end

  defmacrop same_workflow(meta_a, meta_b) do
    quote do
      fragment("?->>'workflow_id' = ?->>'workflow_id'", unquote(meta_a), unquote(meta_b))
    end
  end

  defguardp is_legacy_scheduled(meta)
            when is_map_key(meta, "orig_scheduled_at") and
                   :erlang.map_get("orig_scheduled_at", meta) < 9_999_999_999

  # Telemetry

  @impl Oban.Pro.Handler
  def on_start do
    events = [
      [:oban, :engine, :cancel_all_jobs, :stop],
      [:oban, :plugin, :stop]
    ]

    :telemetry.attach_many("oban.workflow", events, &__MODULE__.handle_event/4, nil)
  end

  @impl Oban.Pro.Handler
  def on_stop do
    :telemetry.detach("oban.workflow")
  end

  def handle_event([:oban, :plugin, _], _time, %{conf: conf, discarded_jobs: jobs}, nil) do
    for %{meta: %{"workflow_id" => workflow_id}} <- jobs do
      handle(workflow_id, conf)
    end
  end

  def handle_event([:oban, :engine, _, _], _time, %{conf: conf, jobs: jobs}, nil) do
    for %{meta: %{"workflow_id" => workflow_id}} <- jobs do
      handle(workflow_id, conf)
    end
  end

  def handle_event(_event, _time, _meta, _conf), do: :ok

  # Handling

  def handle(workflow_id, conf) when is_binary(workflow_id) do
    query = hold_query(%{on_hold: true, workflow_id: workflow_id}, @fin_states)

    conf
    |> Repo.all(query)
    |> Enum.map(&to_stage_operation/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(&apply_operations(&1, conf))
    |> recur_check(conf)
  end

  def rescue_workflows(conf) do
    query = hold_query(%{on_hold: true}, @all_states)

    conf
    |> Repo.all(query)
    |> Enum.map(&to_rescue_operation/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(&apply_operations(&1, conf))
    |> recur_check(conf)
  end

  defp hold_query(condition, states) do
    from(j in Job, as: :jobs)
    |> where([j], j.state == "scheduled")
    |> where([j], fragment("? @> ?", j.meta, ^condition))
    |> select([j], {j, subquery(deps_query(states))})
  end

  defp deps_query(states) do
    # The superfluous `workflow_id` condition is required to match the partial index.
    Job
    |> where([j], name_in_deps(j.meta, parent_as(:jobs).meta))
    |> where([j], fragment("? \\? 'workflow_id'", j.meta))
    |> where([j], same_workflow(j.meta, parent_as(:jobs).meta))
    |> where([j], j.state in ^states)
    |> select([j], fragment("coalesce(array_agg(?), '{}')", j.state))
  end

  defp to_stage_operation({job, []}), do: {:ignore, job}

  defp to_stage_operation({%{meta: meta} = job, deps_states}) do
    op =
      cond do
        length(meta["deps"]) != length(deps_states) ->
          :ignore

        "cancelled" in deps_states and meta["ignore_cancelled"] != true ->
          {:cancelled, :cancelled}

        "discarded" in deps_states and meta["ignore_discarded"] != true ->
          {:cancelled, :discarded}

        is_legacy_scheduled(meta) ->
          {:scheduled, DateTime.from_unix!(meta["orig_scheduled_at"])}

        is_map_key(meta, "orig_scheduled_at") ->
          {:scheduled, DateTime.from_unix!(meta["orig_scheduled_at"], :microsecond)}

        true ->
          :available
      end

    {op, job}
  end

  defp to_rescue_operation({%{meta: meta} = job, deps_states}) do
    deps_set = MapSet.new(deps_states)

    deps_set =
      if length(deps_states) < length(meta["deps"]) do
        MapSet.put(deps_set, "deleted")
      else
        deps_set
      end

    op =
      cond do
        MapSet.member?(deps_set, "deleted") and meta["ignore_deleted"] != true ->
          {:cancelled, :deleted}

        MapSet.member?(deps_set, "cancelled") and meta["ignore_cancelled"] != true ->
          {:cancelled, :cancelled}

        MapSet.member?(deps_set, "discarded") and meta["ignore_discarded"] != true ->
          {:cancelled, :discarded}

        not MapSet.disjoint?(deps_set, @incomplete_set) ->
          :ignore

        is_legacy_scheduled(meta) ->
          {:scheduled, DateTime.from_unix!(meta["orig_scheduled_at"])}

        is_map_key(meta, "orig_scheduled_at") ->
          {:scheduled, DateTime.from_unix!(meta["orig_scheduled_at"], :microsecond)}

        true ->
          :available
      end

    {op, job}
  end

  defp apply_operations({:ignore, _}, _), do: []

  defp apply_operations({op, jobs}, conf) do
    now = DateTime.utc_now()
    ids = Enum.map(jobs, & &1.id)

    base =
      Job
      |> where([j], j.id in ^ids and j.state == "scheduled")
      |> update([j], set: [meta: drop_hold(j.meta)])

    query =
      case op do
        :available ->
          base
          |> select([j], nil)
          |> update([j], set: [scheduled_at: ^now, state: "available"])

        {:scheduled, at} ->
          base
          |> select([j], nil)
          |> update([j], set: [scheduled_at: ^at, state: "scheduled"])

        {:cancelled, reason} ->
          error = %{
            kind: :error,
            reason: Oban.Pro.WorkflowError.exception(reason),
            stacktrace: []
          }

          base
          |> select([j], j.meta["workflow_id"])
          |> update([j],
            set: [cancelled_at: ^now, state: "cancelled"],
            push: [errors: ^Job.format_attempt(%Job{attempt: 1, unsaved_error: error})]
          )
      end

    {_count, workflow_ids} = Repo.update_all(conf, query, set: [])

    with {:cancelled, reason} <- op, do: apply_callbacks(reason, jobs, conf)

    workflow_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp apply_callbacks(reason, jobs, conf) do
    Enum.each(jobs, fn job ->
      with {:ok, worker} <- Oban.Worker.from_string(job.worker),
           true <- function_exported?(worker, :after_cancelled, 2) do
        worker.after_cancelled(reason, %{job | conf: conf})
      end
    end)
  catch
    kind, value ->
      Logger.error(fn ->
        "[Oban.Pro.Workflow] callback error: " <> Exception.format(kind, value, __STACKTRACE__)
      end)

      :ok
  end

  defp recur_check(workflow_ids, conf) do
    workflow_ids
    |> List.flatten()
    |> Enum.each(&handle(&1, conf))
  end
end
