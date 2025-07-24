defmodule Oban.Pro.Migrations.Batch do
  @moduledoc false

  use Ecto.Migration

  def change(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")

    create_if_not_exists index(:oban_jobs, [:state, "(meta->>'batch_id')", "(meta->>'callback')"],
                           name: :oban_jobs_state_meta_batch_index,
                           prefix: prefix,
                           where: "meta ? 'batch_id'"
                         )
  end

  def up(opts \\ []), do: change(opts)

  def down(opts \\ []), do: change(opts)
end
