defmodule Sync.Workers.CustomData.CustomObjectsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Sync.Factory

  alias Sync.Contacts.CustomObject
  alias Sync.Repo
  alias Sync.Workers.CustomData.CustomObjects

  describe "pull_custom_objects/3" do
    test "creates CustomObjects for Avionte models" do
      integration =
        insert(:integration,
          client: :avionte,
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id"
        )

      entity_type_to_model_map = %{
        "talent" => %Sync.Clients.Avionte.Model.Talent{},
        "avionte_contact" => %Sync.Clients.Avionte.Model.AvionteContact{},
        "companies" => %Sync.Clients.Avionte.Model.Company{},
        "placements" => %Sync.Clients.Avionte.Model.Placement{}
      }

      assert :ok = CustomObjects.pull_custom_objects(Sync.Clients.Avionte.Parser, integration, entity_type_to_model_map)

      assert [
               %CustomObject{external_entity_type: "avionte_contact"},
               %CustomObject{external_entity_type: "companies"},
               %CustomObject{external_entity_type: "placements"},
               %CustomObject{external_entity_type: "talent"}
             ] = Repo.all(CustomObject)
    end
  end
end
