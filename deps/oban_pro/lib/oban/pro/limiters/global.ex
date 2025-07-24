defmodule Oban.Pro.Limiters.Global do
  @moduledoc false

  @behaviour Oban.Pro.Limiter

  import Ecto.Query

  alias Oban.Pro.Producer
  alias Oban.Repo

  @impl Oban.Pro.Limiter
  def check(_repo, %{conf: conf, producer: producer}) do
    if is_map(producer.meta.global_limit) do
      check(conf, producer)
    else
      {:ok, nil}
    end
  end

  def check(conf, producer) do
    %{meta: %{global_limit: global_limit}} = producer

    query =
      Producer
      |> where([p], p.queue == ^producer.queue and p.uuid != ^producer.uuid)
      |> where([p], not is_nil(p.meta["global_limit"]["allowed"]))
      |> select([p], p.meta["global_limit"]["tracked"])

    others =
      conf
      |> Repo.all(query)
      |> List.flatten()

    case tracked_to_demands([global_limit.tracked | others], global_limit) do
      [{limit, nil, nil}] -> {:ok, limit}
      demands -> {:ok, demands}
    end
  end

  @impl Oban.Pro.Limiter
  def track(%{global_limit: global_limit} = meta, jobs) when is_map(global_limit) do
    tracked =
      Enum.reduce(jobs, %{}, fn job, acc ->
        {key, worker, args} = job_to_tracked(job, global_limit.partition)

        Map.update(
          acc,
          key,
          %{"args" => args, "count" => 1, "worker" => worker},
          &%{&1 | "count" => &1["count"] + 1}
        )
      end)

    put_in(meta.global_limit.tracked, tracked)
  end

  def track(meta, _jobs), do: meta

  def job_to_key(job, %{meta: %{global_limit: %{partition: partition}}}) do
    {key, _worker, _args} = job_to_tracked(job, partition)

    key
  end

  def job_to_key(_job, _partition), do: nil

  defp job_to_tracked(%{worker: worker, args: args}, partition) do
    case partition do
      %{fields: [:worker], keys: []} ->
        with_hash({worker, nil})

      %{fields: [:args], keys: keys} ->
        with_hash({nil, Map.take(args, keys)})

      %{fields: [_, _], keys: keys} ->
        with_hash({worker, Map.take(args, keys)})

      _ ->
        with_hash({nil, nil})
    end
  end

  defp with_hash({worker, args} = tuple) do
    hash =
      tuple
      |> :erlang.phash2()
      |> to_string()

    {hash, worker, args}
  end

  defp tracked_to_demands(tracked, %{allowed: allowed}) do
    if Enum.all?(tracked, &Enum.empty?/1) do
      [{allowed, nil, nil}]
    else
      tracked
      |> Enum.flat_map(&Map.values/1)
      |> Enum.group_by(&{&1["worker"], &1["args"]})
      |> Enum.map(fn {{worker, args}, group} ->
        total = Enum.reduce(group, 0, &(&1["count"] + &2))

        {max(allowed - total, 0), worker, args}
      end)
    end
  end
end
