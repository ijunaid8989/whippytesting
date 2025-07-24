defmodule Sync.Repo.Migrations.AddWhippyConversationIdToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add(:whippy_conversation_id, :string)
    end
  end
end
