defmodule Oban.Pro.Migrations.Workflow do
  @moduledoc false

  use Ecto.Migration

  def change(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")

    create_if_not_exists index(:oban_jobs, [:state, "(meta->>'workflow_id')", "(meta->>'name')"],
                           name: :oban_jobs_state_meta_workflow_index,
                           prefix: prefix,
                           where: "meta ? 'workflow_id'"
                         )
  end

  def up(opts \\ []), do: change(opts)

  def down(opts \\ []), do: change(opts)
end
