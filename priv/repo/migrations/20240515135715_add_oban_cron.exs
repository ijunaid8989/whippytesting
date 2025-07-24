defmodule Sync.Repo.Migrations.AddObanCron do
  use Ecto.Migration

  defdelegate change, to: Oban.Pro.Migrations.DynamicCron
end
