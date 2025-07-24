defmodule Sync.ContactsTest do
  use Sync.DataCase

  import Sync.Factory

  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Contacts.CustomPropertyValue

  describe "contacts" do
    test "list_contacts_not_converted_to_custom_object_records/2 returns contacts not converted to custom object records" do
      integration = insert(:integration, client: :tempworks)

      contact_one =
        insert(:contact,
          integration: integration,
          external_contact_id: "1",
          whippy_organization_id: integration.whippy_organization_id,
          external_organization_id: integration.external_organization_id,
          whippy_contact_id: "1"
        )

      %{id: contact_two_id} =
        insert(:contact,
          integration: integration,
          phone: "123-456-7890",
          external_contact_id: "2",
          whippy_organization_id: integration.whippy_organization_id,
          external_organization_id: integration.external_organization_id,
          whippy_contact_id: "2"
        )

      custom_object = insert(:custom_object, integration: integration)

      insert(:custom_object_record,
        custom_object: custom_object,
        integration: integration,
        external_custom_object_record_id: contact_one.external_contact_id
      )

      assert [%Contact{id: ^contact_two_id}] =
               Contacts.list_contacts_not_converted_to_custom_object_records(integration, 100, custom_object.id)
    end

    test "list_integration_synced_external_contact_ids/1 returns a list of external IDs" do
      integration = insert(:integration, client: :tempworks)

      _synced__contact =
        insert(:contact,
          integration: integration,
          external_contact_id: "1",
          whippy_organization_id: integration.whippy_organization_id,
          external_organization_id: integration.external_organization_id,
          whippy_contact_id: "1"
        )

      _unsynced_contact =
        insert(:contact,
          integration: integration,
          phone: "123-456-7890",
          external_contact_id: nil,
          whippy_organization_id: integration.whippy_organization_id,
          external_organization_id: nil,
          whippy_contact_id: "2"
        )

      assert ["1"] = Contacts.list_integration_synced_external_contact_ids(integration)
    end
  end

  describe "save_external_contacts" do
    setup do
      integration = insert(:integration, client: :tempworks)
      {:ok, integration: integration}
    end

    test "successfully saves new external contacts", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"},
          external_channel_id: "channel_1"
        },
        %{
          external_contact_id: "contact_2",
          name: "Jane Smith",
          email: "jane@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "contact_2", "name" => "Jane Smith"},
          external_channel_id: "channel_2"
        }
      ]

      result = Contacts.save_external_contacts(integration, contacts)

      # Verify contacts were created
      saved_contacts = Contacts.list_integration_contacts_missing_from_whippy(integration, 100, 0)
      assert length(saved_contacts) == 2

      contact_1 = Enum.find(saved_contacts, &(&1.external_contact_id == "contact_1"))
      contact_2 = Enum.find(saved_contacts, &(&1.external_contact_id == "contact_2"))

      assert contact_1.name == "John Doe"
      assert contact_1.email == "john@example.com"
      assert contact_1.phone == "+14064107688"
      assert contact_1.should_sync_to_whippy == true
      assert contact_1.external_contact_hash != nil

      assert contact_2.name == "Jane Smith"
      assert contact_2.email == "jane@example.com"
      assert contact_2.phone == "+19569291019"
      assert contact_2.should_sync_to_whippy == true
      assert contact_2.external_contact_hash != nil
    end

    test "updates existing contacts when external_contact_id already exists", %{integration: integration} do
      # Create an existing contact
      existing_contact =
        insert(:contact,
          integration: integration,
          external_contact_id: "existing_contact",
          external_organization_id: integration.external_organization_id,
          name: "Old Name",
          email: "old@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "existing_contact", "name" => "Old Name"},
          should_sync_to_whippy: false
        )

      # Update the contact with new data
      contacts = [
        %{
          external_contact_id: "existing_contact",
          name: "Updated Name",
          email: "updated@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "existing_contact", "name" => "Updated Name"},
          external_channel_id: "channel_1"
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      # Verify contact was updated
      updated_contact = Contacts.get_contact_by_external_id(integration.id, "existing_contact")
      assert updated_contact.name == "Updated Name"
      assert updated_contact.email == "updated@example.com"
      assert updated_contact.should_sync_to_whippy == true
      assert updated_contact.external_contact_hash != existing_contact.external_contact_hash
    end

    test "handles duplicate phone numbers by keeping only unique contacts", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"}
        },
        %{
          external_contact_id: "contact_2",
          name: "Jane Smith",
          email: "jane@example.com",
          # Same phone number
          phone: "+19569291019",
          external_contact: %{"id" => "contact_2", "name" => "Jane Smith"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      # Only one contact should be saved due to phone uniqueness
      saved_contacts = Contacts.list_integration_contacts_missing_from_whippy(integration, 100, 0)
      assert length(saved_contacts) == 1
    end

    test "formats phone numbers using Formatter", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          # Unformatted phone
          phone: "(956) 929-1019",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      # Should be formatted to E.164
      assert saved_contact.phone == "+19569291019"
    end

    test "sets should_sync_to_whippy to false when contact hash hasn't changed", %{integration: integration} do
      # Create an existing contact with specific hash
      existing_contact =
        insert(:contact,
          integration: integration,
          external_contact_id: "unchanged_contact",
          external_organization_id: integration.external_organization_id,
          name: "John Doe",
          email: "john@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "unchanged_contact", "name" => "John Doe"},
          external_contact_hash: Contacts.calculate_hash(%{"id" => "unchanged_contact", "name" => "John Doe"})
        )

      # Try to save the same contact data
      contacts = [
        %{
          external_contact_id: "unchanged_contact",
          name: "John Doe",
          email: "john@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "unchanged_contact", "name" => "John Doe"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      # Contact should not be marked for sync since data hasn't changed
      updated_contact = Contacts.get_contact_by_external_id(integration.id, "unchanged_contact")
      assert updated_contact.should_sync_to_whippy == false
    end

    test "sets should_sync_to_whippy to true when contact hash has changed", %{integration: integration} do
      # Create an existing contact
      existing_contact =
        insert(:contact,
          integration: integration,
          external_contact_id: "changed_contact",
          external_organization_id: integration.external_organization_id,
          name: "John Doe",
          email: "john@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "changed_contact", "name" => "John Doe"},
          should_sync_to_whippy: false
        )

      # Update with changed data
      contacts = [
        %{
          external_contact_id: "changed_contact",
          name: "John Doe Updated",
          email: "john.updated@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "changed_contact", "name" => "John Doe Updated"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      # Contact should be marked for sync since data has changed
      updated_contact = Contacts.get_contact_by_external_id(integration.id, "changed_contact")
      assert updated_contact.should_sync_to_whippy == true
      assert updated_contact.name == "John Doe Updated"
      assert updated_contact.email == "john.updated@example.com"
    end

    test "handles large batches by chunking into groups of 100", %{integration: integration} do
      # Create 250 contacts to test chunking
      contacts =
        for i <- 1..100 do
          %{
            external_contact_id: "contact_1#{i}",
            name: "Contact 1#{i}",
            email: "contact#{i}@example.com",
            phone:
              "+195691#{:rand.uniform(4)}#{:rand.uniform(9)}#{:rand.uniform(8)}#{:rand.uniform(8)}#{:rand.uniform(6)}",
            external_contact: %{"id" => "contact_#{i}", "name" => "Contact #{i}"}
          }
        end

      [{number_of_contacts, _}] =
        Contacts.save_external_contacts(integration, contacts)

      # Verify all contacts were saved
      saved_contacts = Contacts.list_integration_contacts_missing_from_whippy(integration, 300, 0)
      assert length(saved_contacts) == number_of_contacts
    end

    test "handles large batches, If there is error process individual contacts", %{integration: integration} do
      existing_contact =
        insert(:contact,
          integration: integration,
          external_contact_id: "changed_contact",
          external_organization_id: integration.external_organization_id,
          name: "John Doe",
          email: "john@example.com",
          phone: "+19569291019",
          external_contact: %{"id" => "changed_contact", "name" => "John Doe"},
          should_sync_to_whippy: false
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "updated_contact",
        external_organization_id: integration.external_organization_id,
        name: "John Doe",
        email: "john1@example.com",
        phone: "+19569291011",
        external_contact: %{"id" => "updated_contact", "name" => "John Doe"},
        should_sync_to_whippy: false
      )

      # Update with changed data
      contacts = [
        # External Id exists in the database
        %{
          external_contact_id: "changed_contact",
          name: "John Doe Updated",
          email: "john.updated@example.com",
          phone: "+19569291011",
          external_contact: %{"id" => "changed_contact", "name" => "John Doe Updated"}
        },
        # External Id does not exist
        %{
          external_contact_id: "contact_2",
          name: "Jane Smith",
          email: "jane2@example.com",
          phone: "+19569291119",
          external_contact: %{"id" => "contact_2", "name" => "Jane Smith"},
          external_channel_id: "channel_2"
        }
      ]

      [{1, [%Contact{external_contact_id: external_contact_id}]}] =
        Contacts.save_external_contacts(integration, contacts)

      assert external_contact_id = "contact_2"
      assert Repo.get_by(Contact, external_contact_id: "contact_2") != nil
    end

    test "sets errors field to empty map for new contacts", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.errors == %{}
    end

    test "handles contacts with nil phone numbers", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: nil,
          external_contact: %{"id" => "contact_1", "name" => "John Doe"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact == nil
      # assert saved_contact.phone == nil
    end

    test "handles contacts with external_channel_id and sets whippy_channel_id", %{integration: integration} do
      # Create a channel for the integration
      channel =
        insert(:channel,
          integration: integration,
          external_channel_id: "external_channel_1",
          whippy_channel_id: "whippy_channel_1"
        )

      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"},
          external_channel_id: "external_channel_1"
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.whippy_channel_id == "whippy_channel_1"
      assert saved_contact.external_channel_id == "external_channel_1"
    end

    test "handles contacts without external_channel_id", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          external_contact: %{"id" => "contact_1", "name" => "John Doe"}
          # No external_channel_id
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.whippy_channel_id == nil
      assert saved_contact.external_channel_id == nil
    end

    test "handles empty contacts list", %{integration: integration} do
      result = Contacts.save_external_contacts(integration, [])

      # Should not raise any errors
      assert result == []
    end

    test "handles contacts with birth_date", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          birth_date: "1990-01-01",
          external_contact: %{"id" => "contact_1", "name" => "John Doe", "birth_date" => "1990-01-01"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.birth_date == "1990-01-01"
    end

    test "handles contacts with address data", %{integration: integration} do
      address_data = %{
        "street" => "123 Main St",
        "city" => "New York",
        "state" => "NY",
        "zip" => "10001"
      }

      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          address: address_data,
          external_contact: %{"id" => "contact_1", "name" => "John Doe", "address" => address_data}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.address == address_data
    end

    test "handles contacts with external_organization_entity_type", %{integration: integration} do
      contacts = [
        %{
          external_contact_id: "contact_1",
          name: "John Doe",
          email: "john@example.com",
          phone: "+14064107688",
          external_organization_entity_type: "employee",
          external_contact: %{"id" => "contact_1", "name" => "John Doe", "type" => "employee"}
        }
      ]

      Contacts.save_external_contacts(integration, contacts)

      saved_contact = Contacts.get_contact_by_external_id(integration.id, "contact_1")
      assert saved_contact.external_organization_entity_type == "employee"
    end
  end

  describe "custom_objects" do
    setup do
      integration = insert(:integration, client: :tempworks)

      {:ok, integration: integration}
    end

    test "list_custom_objects/0 returns all custom_objects" do
      custom_object = insert(:custom_object)
      assert [%CustomObject{}] = Contacts.list_custom_objects(custom_object.whippy_organization_id)
    end

    test "create_custom_object/1 creates a custom_object", %{integration: integration} do
      attrs = params_for(:custom_object, integration_id: integration.id, external_entity_type: "employee")
      {:ok, custom_object} = Contacts.create_custom_object(attrs)
      assert custom_object.whippy_organization_id == attrs.whippy_organization_id
      assert custom_object.whippy_custom_object_id == attrs.whippy_custom_object_id
      assert custom_object.whippy_custom_object == attrs.whippy_custom_object
      assert custom_object.external_custom_object == attrs.external_custom_object
      assert custom_object.custom_object_mapping == attrs.custom_object_mapping
      assert custom_object.external_entity_type == attrs.external_entity_type
    end

    test "create_custom_object/1 returns unique constraint error when attempting to create a duplicate custom object",
         %{integration: integration} do
      attrs = params_for(:custom_object, integration_id: integration.id, external_entity_type: "employee")

      {:ok, _} = Contacts.create_custom_object(attrs)
      {:error, _} = Contacts.create_custom_object(attrs)
    end

    test "create_custom_object/1 sets the external_entity_type to custom_data if unknown entity_type is provided", %{
      integration: integration
    } do
      attrs = params_for(:custom_object, integration_id: integration.id, external_entity_type: "prescription")

      {:ok, %CustomObject{external_entity_type: "custom_data"}} = Contacts.create_custom_object(attrs)
    end

    test """
    create_custom_object/1 returns an error when attempting to create custom object that belongs to an integration
    with a client for which we don't have custom data support
    """ do
      integration = insert(:integration, client: :loxo)
      attrs = params_for(:custom_object, integration_id: integration.id, external_entity_type: nil)

      {:error,
       %Ecto.Changeset{
         errors: [external_entity_type: {"no external entity types supported for integration with loxo", []}]
       }} =
        Contacts.create_custom_object(attrs)
    end

    test "get_custom_property/2 returns a custom property by a whippy key", %{integration: integration} do
      custom_object = insert(:custom_object, integration: integration)

      insert(:custom_property,
        custom_object_id: custom_object.id,
        whippy_custom_property: %{"label" => "Name", "key" => "name"}
      )

      assert %CustomProperty{} = Contacts.get_custom_property(custom_object.id, "name")
      assert nil == Contacts.get_custom_property(custom_object.id, "non-existent label")
    end

    test """
    create_external_custom_properties/1 upserts custom properties and sets should_send_to_whippy as true
    when the external custom properties map contains changes
    """ do
      integration = insert(:integration, client: :tempworks)
      custom_object = insert(:custom_object, integration: integration)

      existing_custom_property =
        insert(:custom_property,
          should_sync_to_whippy: false,
          integration: integration,
          custom_object: custom_object,
          external_custom_property: %{"key" => "email", "label" => "Email", "type" => "text"}
        )

      external_custom_properties_attrs = [
        %{
          integration_id: integration.id,
          custom_object_id: custom_object.id,
          external_organization_id: integration.external_organization_id,
          whippy_organization_id: custom_object.whippy_organization_id,
          whippy_custom_object_id: custom_object.whippy_custom_object_id,
          external_custom_property: %{key: "name", label: "Name", type: "text"}
        },
        %{
          integration_id: integration.id,
          custom_object_id: custom_object.id,
          external_organization_id: integration.external_organization_id,
          whippy_organization_id: custom_object.whippy_organization_id,
          whippy_custom_object_id: custom_object.whippy_custom_object_id,
          external_custom_property: %{
            key: "email",
            label: "Email",
            type: "text",
            references: [
              %{type: "one_to_many", external_entity_type: "employee", external_entity_property_key: "employee_id"}
            ]
          }
        }
      ]

      Contacts.create_external_custom_properties(external_custom_properties_attrs)
      assert %CustomProperty{should_sync_to_whippy: true} = Repo.reload(existing_custom_property)
    end

    test "create_custom_object_with_custom_properties/2 creates a custom_object with custom_properties ",
         %{integration: integration} do
      attrs = %{
        whippy_organization_id: "5a701537-c1c9-49c7-8180-10f3bc7393ce",
        integration_id: integration.id,
        external_entity_type: "employee",
        whippy_custom_object_id: "a9bd108b-3faf-4610-b349-cadc9fb484e8",
        whippy_custom_object: %{},
        custom_properties: [
          %{
            whippy_organization_id: "5a701537-c1c9-49c7-8180-10f3bc7393ce",
            whippy_custom_property_id: "028e7895-b367-40e4-a4e1-e6d9b38c3825",
            whippy_custom_object_id: "a9bd108b-3faf-4610-b349-cadc9fb484e8",
            whippy_custom_property: %{}
          }
        ]
      }

      assert {:ok,
              %CustomObject{
                external_entity_type: "employee",
                whippy_custom_object_id: "a9bd108b-3faf-4610-b349-cadc9fb484e8",
                custom_properties: [custom_property]
              }} = Contacts.create_custom_object_with_custom_properties(attrs)

      assert %CustomProperty{
               whippy_organization_id: "5a701537-c1c9-49c7-8180-10f3bc7393ce",
               whippy_custom_object_id: "a9bd108b-3faf-4610-b349-cadc9fb484e8"
             } = custom_property
    end

    test "create_custom_object_record_with_custom_property_values/1 with valid params creates records" do
      custom_object = insert(:custom_object)
      custom_object_record = insert(:custom_object_record, custom_object_id: custom_object.id)
      custom_property_value = insert(:custom_property_value, custom_object_record_id: custom_object_record.id)

      params = %{
        custom_object_id: custom_object.id,
        integration_id: custom_object.integration_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
        external_custom_object_record_id: "123",
        custom_property_values: [
          %{
            integration_id: custom_object.integration_id,
            custom_property_id: custom_property_value.custom_property_id,
            whippy_organization_id: custom_object.whippy_organization_id,
            whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
            whippy_custom_property_id: custom_property_value.whippy_custom_property_id,
            whippy_custom_property_value_id: custom_property_value.whippy_custom_property_value_id,
            whippy_custom_property_value: custom_property_value.whippy_custom_property_value
          }
        ]
      }

      assert {:ok,
              %CustomObjectRecord{custom_property_values: [%CustomPropertyValue{custom_property: %CustomProperty{}}]}} =
               Contacts.create_custom_object_record_with_custom_property_values(params)
    end

    test "create_custom_object_record_with_custom_property_values/1 updates existing record when attempting to insert duplicate record" do
      custom_object = insert(:custom_object)

      custom_object_record =
        insert(:custom_object_record, custom_object_id: custom_object.id, external_custom_object_record_id: "123")

      attrs = %{
        custom_object_id: custom_object.id,
        integration_id: custom_object.integration_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
        external_custom_object_record: %{"name" => "Bob Marley"},
        external_custom_object_record_id: "123",
        custom_property_values: []
      }

      assert {:ok, %CustomObjectRecord{id: id}} = Contacts.create_custom_object_record_with_custom_property_values(attrs)
      assert {:ok, %CustomObjectRecord{id: ^id}} = Contacts.create_custom_object_record_with_custom_property_values(attrs)
    end

    test """
    create_custom_object_record_with_custom_property_values/1 while upserting, sets should_sync_to_whippy field to true
    when the external_custom_object_record map contains changes
    """ do
      custom_object = insert(:custom_object)

      custom_object_record =
        insert(:custom_object_record,
          custom_object_id: custom_object.id,
          external_custom_object_record_id: "123",
          external_custom_object_record: %{"name" => "John Doe"}
        )

      params = %{
        custom_object_id: custom_object.id,
        integration_id: custom_object.integration_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
        external_custom_object_record: %{"name" => "Bob Marley"},
        external_custom_object_record_id: "123",
        custom_property_values: []
      }

      assert {:ok, %CustomObjectRecord{should_sync_to_whippy: true}} =
               Contacts.create_custom_object_record_with_custom_property_values(params)
    end

    test """
    create_custom_object_record_with_custom_property_values/1 while upserting, sets should_sync_to_whippy field to true
    when a new custom property value is added to the custom object record
    """ do
      custom_object = insert(:custom_object)

      custom_object_record =
        insert(:custom_object_record,
          custom_object_id: custom_object.id,
          external_custom_object_record_id: "123",
          external_custom_object_record: %{"name" => "John Doe"}
        )

      custom_property =
        insert(:custom_property,
          custom_object_id: custom_object.id,
          whippy_custom_property_id: "123",
          whippy_custom_property: %{"key" => "name"}
        )

      params = %{
        custom_object_id: custom_object.id,
        integration_id: custom_object.integration_id,
        whippy_organization_id: custom_object.whippy_organization_id,
        whippy_custom_object_id: custom_object.whippy_custom_object_id,
        whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
        external_custom_object_record: %{"name" => "John Doe"},
        external_custom_object_record_id: "123",
        custom_property_values: [
          %{
            integration_id: custom_object.integration_id,
            custom_property_id: custom_property.id,
            whippy_custom_property_id: custom_property.whippy_custom_property_id,
            external_custom_property_value: "John Doe"
          }
        ]
      }

      assert {:ok, %CustomObjectRecord{should_sync_to_whippy: true}} =
               Contacts.create_custom_object_record_with_custom_property_values(params)
    end

    test """
    update_custom_object_record_synced_in_whippy/4 updates the custom object record with the given whippy values
    """ do
      integration = insert(:integration, client: :tempworks)
      custom_object = insert(:custom_object, integration: integration)

      custom_property =
        insert(:custom_property,
          integration: integration,
          custom_object_id: custom_object.id,
          whippy_custom_property_id: "123"
        )

      %{id: custom_object_record_id} =
        custom_object_record =
        insert(:custom_object_record,
          integration: integration,
          custom_object_id: custom_object.id,
          should_sync_to_whippy: true
        )

      custom_property_value =
        insert(:custom_property_value,
          custom_object_record_id: custom_object_record_id,
          whippy_custom_property_id: custom_property.whippy_custom_property_id,
          whippy_custom_property_value: nil,
          external_custom_property_value: "New York"
        )

      whippy_custom_object_record = %{
        whippy_custom_object_id: "some whippy id",
        whippy_custom_object_record_id: "1234",
        whippy_custom_object_record: %{},
        custom_property_values: [
          %{
            whippy_custom_object_record_id: custom_object_record.whippy_custom_object_record_id,
            whippy_custom_property_id: custom_property.whippy_custom_property_id,
            whippy_custom_property_value_id: custom_property_value.whippy_custom_property_value_id,
            whippy_custom_property_value: "New York"
          }
        ]
      }

      assert {:ok,
              %CustomObjectRecord{
                id: ^custom_object_record_id,
                should_sync_to_whippy: false,
                whippy_custom_object_record_id: "1234",
                custom_property_values: [
                  %CustomPropertyValue{whippy_custom_property_value: "New York"}
                ]
              }} =
               Contacts.update_custom_object_record_synced_in_whippy(
                 integration,
                 custom_object_record,
                 "1234",
                 whippy_custom_object_record
               )
    end

    test "update_custom_object_synced_in_whippy/3 updates the custom object with the given whippy values" do
      integration = insert(:integration, client: :tempworks)

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "employee", whippy_custom_object_id: nil)

      insert(:custom_property,
        integration: integration,
        custom_object_id: custom_object.id,
        whippy_custom_property_id: nil,
        whippy_custom_property: %{},
        external_custom_property: %{"key" => "name", "label" => "Name", "type" => "string"}
      )

      assert {:ok,
              %CustomObject{
                whippy_custom_object_id: "1234",
                custom_properties: [
                  %CustomProperty{whippy_custom_property_id: "4321"}
                ]
              }} =
               Contacts.update_custom_object_synced_in_whippy(
                 integration,
                 custom_object,
                 %{
                   external_entity_type: "employee",
                   whippy_custom_object_id: "1234",
                   whippy_custom_object: %{key: "employee", label: "Employee"},
                   custom_properties: [
                     %{
                       whippy_custom_object_id: "1234",
                       whippy_custom_property_id: "4321",
                       whippy_custom_property: %{key: "name", label: "Name", type: "string"}
                     }
                   ]
                 }
               )
    end
  end
end
