defmodule Sync.Repo.Migrations.AddUniqueConstraintToActivityContactsOnWhippyMessageIdAndContactId do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      unique_index(
        :activities_contacts,
        [:activity_id, :external_contact_id, :whippy_contact_id],
        nulls_distinct: false
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(:activities_contacts, [:activity_id, :external_contact_id, :whippy_contact_id],
        nulls_distinct: false
      )
    )
  end
end
