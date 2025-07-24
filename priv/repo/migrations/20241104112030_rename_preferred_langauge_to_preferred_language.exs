defmodule Sync.Repo.Migrations.RenamePreferredLangaugeToPreferredLanguage do
  use Ecto.Migration

  def change do
    rename table(:contacts), :preferred_langauge, to: :preferred_language
  end
end
