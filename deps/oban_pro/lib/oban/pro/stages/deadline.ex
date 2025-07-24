defmodule Oban.Pro.Stages.Deadline do
  @moduledoc false

  @behaviour Oban.Pro.Stage

  alias Oban.Pro.Utils
  alias Oban.{Registry, Validation}

  @time_units ~w(
    second
    seconds
    minute
    minutes
    hour
    hours
    day
    days
    week
    weeks
  )a

  defstruct [:in, force: false]

  @impl Oban.Pro.Stage
  def init(worker \\ nil, period)

  def init(worker, period) when is_integer(period) or is_tuple(period) do
    init(worker, in: period)
  end

  def init(_worker, opts) when is_list(opts) do
    with :ok <- validate(opts) do
      conf =
        opts
        |> Keyword.update!(:in, &Utils.cast_period/1)
        |> then(&struct(__MODULE__, &1))

      {:ok, conf}
    end
  end

  @impl Oban.Pro.Stage
  def before_new(args, opts, conf) do
    {deadline, opts} = Keyword.pop(opts, :deadline, conf.in)

    seconds = Utils.cast_period(deadline)
    now = DateTime.utc_now()

    offset =
      cond do
        schedule_in = opts[:schedule_in] -> Utils.cast_period(schedule_in) + seconds
        scheduled_at = opts[:scheduled_at] -> DateTime.diff(scheduled_at, now) + seconds
        true -> seconds
      end

    at =
      now
      |> DateTime.add(offset)
      |> DateTime.to_unix()

    meta = %{"deadline_at" => at}
    opts = Keyword.update(opts, :meta, meta, &Map.merge(&1, meta))

    {:ok, args, opts}
  end

  @impl Oban.Pro.Stage
  def before_process(%{meta: %{"deadline_at" => at}} = job, conf) do
    now = DateTime.utc_now()
    dat = DateTime.from_unix!(at)

    if :gt == DateTime.compare(now, dat) do
      {:cancel, "deadline at #{inspect(dat)} exired"}
    else
      if conf.force, do: force_timeout(now, dat, job)

      {:ok, job}
    end
  end

  defp force_timeout(now, dat, job) do
    parent = self()

    Task.start(fn ->
      ref = Process.monitor(parent)

      Process.send_after(self(), :cancel, DateTime.diff(dat, now, :millisecond))

      receive do
        {:DOWN, ^ref, :process, _pid, _reason} ->
          Process.demonitor(ref, [:flush])

        :cancel ->
          with pid when is_pid(pid) <- Registry.whereis(job.conf.name, {:producer, job.queue}) do
            payload = %{"action" => "pkill", "job_id" => job.id}

            send(pid, {:notification, :signal, payload})
          end
      end
    end)
  end

  # Validation

  defp validate(opts) do
    Validation.validate_schema(opts,
      in: {:custom, &validate_period/1},
      force: :boolean
    )
  end

  defp validate_period(period) when is_integer(period), do: :ok
  defp validate_period({value, units}) when is_integer(value) and units in @time_units, do: :ok

  defp validate_period(period) do
    {:error, "expected deadline to be an integer in seconds or a tuple, got: #{inspect(period)}"}
  end
end
