defmodule Oban.Pro.Limiter do
  @moduledoc false

  alias Oban.Pro.Producer
  alias Oban.{Config, Job}

  @type changes :: %{
          :conf => Config.t(),
          :prod => Producer.t(),
          :running => map(),
          optional(atom()) => any()
        }

  @type demand :: non_neg_integer()

  @type rate_limit :: nil | demand | [{demand, term(), term()}]
  @type repo :: Ecto.Repo.t()

  @doc """
  Calculate the current demand based on capacity and usage.
  """
  @callback check(repo(), changes()) :: {:ok, rate_limit()}

  @doc """
  Record demand usage.
  """
  @callback track(Producer.meta(), [Job.t()]) :: Producer.meta()
end
