defmodule Oban.Pro.Limiters.Local do
  @moduledoc false

  @behaviour Oban.Pro.Limiter

  @impl Oban.Pro.Limiter
  def check(_repo, %{producer: producer, running: running}) do
    {:ok, producer.meta.local_limit - map_size(running)}
  end

  @impl Oban.Pro.Limiter
  def track(meta, _jobs), do: meta
end
