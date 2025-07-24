defmodule Sync.Repo.Migrations.PopulateMissingAssociatedResourceIdsForAvionteIntegrations do
  use Ecto.Migration

  import Ecto.Query

  alias Sync.Repo

  # Some Аvionte Talent (custom object record) records were missing associated_resource_id
  # This migration will populate the missing associated_resource_id for those records
  def change do
    from(i in "integrations", where: i.client == "avionte")
    |> select([i], i.id)
    |> Repo.all()
    |> Enum.each(fn integration_id ->
      from(cor in "custom_object_records",
        where: cor.integration_id == ^integration_id and is_nil(cor.whippy_associated_resource_id)
      )
      |> join(:inner, [cor], c in "contacts",
        on: cor.external_custom_object_record_id == c.external_contact_id
      )
      |> where([cor, c], not is_nil(c.whippy_contact_id))
      |> update([cor, c],
        set: [
          whippy_associated_resource_id: c.whippy_contact_id,
          should_sync_to_whippy: true,
          errors: ^%{}
        ]
      )
      |> Repo.update_all([], timeout: :timer.minutes(30))
    end)
  end
end
