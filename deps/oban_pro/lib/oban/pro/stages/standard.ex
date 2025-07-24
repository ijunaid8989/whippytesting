defmodule Oban.Pro.Stages.Standard do
  @moduledoc false

  @behaviour Oban.Pro.Stage

  alias Oban.{Job, Validation}

  @impl Oban.Pro.Stage
  def init(_worker \\ nil, opts) do
    with :ok <- validate(opts), do: {:ok, []}
  end

  defp validate(opts) do
    Validation.validate_schema(opts,
      max_attempts: :pos_integer,
      priority: {:range, 0..9},
      queue: {:or, [:atom, :string]},
      replace: {:custom, &Job.validate_replace/1},
      tags: {:list, :string},
      unique: {:custom, &Job.validate_unique/1},
      worker: :string
    )
  end
end
