defmodule Sync.Repo.Migrations.UpdateSendContactsToExternalIntegrationsToTrueForAvionteAndTempworksClients do
  use Ecto.Migration

  import Ecto.Query
  alias Sync.Repo

  def up do
    from(i in "integrations",
      where: i.client in ["avionte", "tempworks"],
      update: [
        set: [
          settings:
            fragment(
              "jsonb_set(settings, '{send_contacts_to_external_integrations}', 'true'::jsonb)"
            )
        ]
      ]
    )
    |> Repo.update_all([])
  end

  def down do
    from(i in "integrations",
      where: i.client in ["avionte", "tempworks"],
      update: [
        set: [
          settings:
            fragment(
              "jsonb_set(settings, '{send_contacts_to_external_integrations}', 'false'::jsonb)"
            )
        ]
      ]
    )
    |> Repo.update_all([])
  end
end
