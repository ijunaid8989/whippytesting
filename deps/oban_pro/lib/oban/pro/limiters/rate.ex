defmodule Oban.Pro.Limiters.Rate do
  @moduledoc false

  @behaviour Oban.Pro.Limiter

  import Ecto.Query

  alias Oban.Pro.Producer
  alias Oban.Repo

  @impl Oban.Pro.Limiter
  def check(_repo, %{conf: conf, producer: producer}) do
    if is_map(producer.meta.rate_limit) do
      check(conf, producer)
    else
      {:ok, nil}
    end
  end

  @doc false
  def check(conf, producer) do
    query =
      Producer
      |> where([p], p.queue == ^producer.queue)
      |> where([p], not is_nil(p.meta["rate_limit"]["period"]))
      |> select([p], p.meta["rate_limit"])

    conf
    |> Repo.all(query)
    |> Enum.filter(&within_window?(&1, unix_now()))
    |> Enum.flat_map(& &1["windows"])
    |> windows_to_limits(producer.meta.rate_limit)
    |> case do
      [{limit, nil, nil}] -> {:ok, limit}
      demands -> {:ok, demands}
    end
  end

  @impl Oban.Pro.Limiter
  def track(%{rate_limit: rate_limit} = meta, jobs) when is_map(rate_limit) do
    %{partition: partition} = rate_limit

    new_mapping =
      Enum.reduce(jobs, %{}, fn job, acc ->
        pkey = job_to_pkey(job, partition)

        {worker, args} = pkey

        base = %{"curr_count" => 1, "prev_count" => 0, "worker" => worker, "args" => args}

        Map.update(acc, pkey, base, &%{&1 | "curr_count" => &1["curr_count"] + 1})
      end)

    old_window_keys = Enum.map(rate_limit.windows, &window_to_pkey(&1, partition))

    new_windows =
      new_mapping
      |> Map.drop(old_window_keys)
      |> Map.values()

    prev_unix = maybe_to_unix(rate_limit.window_time)
    unix_diff = unix_now() - prev_unix

    {mode, next_time} =
      cond do
        unix_diff > rate_limit.period * 2 -> {:dump_prev, unix_now()}
        unix_diff > rate_limit.period -> {:swap_prev, unix_now()}
        true -> {:bump_curr, prev_unix}
      end

    all_windows =
      rate_limit.windows
      |> Enum.map(&put_next_count(&1, mode, new_mapping, partition))
      |> Enum.reject(&empty_window?/1)
      |> Enum.concat(new_windows)

    %{meta | rate_limit: %{rate_limit | windows: all_windows, window_time: next_time}}
  end

  def track(meta, _jobs), do: meta

  def within_window?(%{"period" => period, "window_time" => prev_time}, curr_unix) do
    maybe_to_unix(prev_time) >= curr_unix - period
  end

  def windows_to_limits([], %{allowed: allowed}) do
    [{allowed, nil, nil}]
  end

  def windows_to_limits(windows, rate_limit) do
    %{allowed: allowed, period: period, window_time: prev_time} = rate_limit

    ellapsed = unix_now() - maybe_to_unix(prev_time)
    weight = div(max(period - ellapsed, 0), period)

    windows
    |> Enum.group_by(&{&1["worker"], &1["args"]})
    |> Enum.map(fn {{worker, args}, group} ->
      curr_total = Enum.reduce(group, 0, &(&1["curr_count"] + &2))
      prev_total = Enum.reduce(group, 0, &(&1["prev_count"] + &2))

      limit = allowed - (prev_total * weight + curr_total)

      {max(limit, 0), worker, args}
    end)
  end

  # Time Helpers

  defp unix_now do
    DateTime.to_unix(DateTime.utc_now(), :second)
  end

  defp maybe_to_unix(unix) when is_integer(unix) do
    unix
  end

  defp maybe_to_unix(time) do
    Date.utc_today()
    |> DateTime.new!(Time.from_iso8601!(time))
    |> DateTime.to_unix(:second)
  end

  # Track Helpers

  defp job_to_pkey(job, partition) do
    window_to_pkey(%{"worker" => job.worker, "args" => job.args}, partition)
  end

  defp window_to_pkey(window, partition) do
    case partition do
      %{fields: [:worker], keys: []} ->
        {window["worker"], nil}

      %{fields: [:args], keys: keys} ->
        args =
          window
          |> Map.fetch!("args")
          |> Map.take(keys)

        {nil, args}

      %{fields: [_, _], keys: keys} ->
        args =
          window
          |> Map.fetch!("args")
          |> Map.take(keys)

        {window["worker"], args}

      _ ->
        {nil, nil}
    end
  end

  defp put_next_count(window, mode, mapping, partition) do
    %{"curr_count" => curr_count, "prev_count" => prev_count} = window

    next_count = get_in(mapping, [window_to_pkey(window, partition), "curr_count"]) || 0

    {curr_count, prev_count} =
      case mode do
        :dump_prev -> {next_count, 0}
        :swap_prev -> {next_count, curr_count}
        :bump_curr -> {curr_count + next_count, prev_count}
      end

    %{window | "curr_count" => curr_count, "prev_count" => prev_count}
  end

  defp empty_window?(window), do: match?(%{"curr_count" => 0, "prev_count" => 0}, window)
end
