defmodule Sync.Webhooks.TempworksTest do
  use Sync.DataCase, async: false

  import Mock
  import Sync.Factory
  import Sync.Fixtures.TempworksClient

  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Contacts.Contact
  alias Sync.Webhooks.Tempworks

  @employee_update_payload %{
    "subscriptionId" => 29,
    "timestamp" => "2025-03-26T15:58:36.0943424+00:00",
    "eventName" => "employee.updated",
    "tenantName" => "Whippy",
    "payload" => %{
      "employeeId" => 49_453,
      "employeeGuid" => "9b7c7f90-accf-4f69-b7ea-d800b05959fb",
      "firstName" => "Bunny11",
      "lastName" => "- Test",
      "isActive" => true,
      "activationDate" => "2025-02-03T04:30:00",
      "primaryPhoneNumber" => "+923330671784",
      "primaryEmailAddress" => "jack@whippy.co",
      "employeeStatusId" => "A",
      "address" => %{
        "attentionTo" => nil,
        "street1" => nil,
        "street2" => nil,
        "municipality" => nil,
        "region" => "CA",
        "postalCode" => nil,
        "country" => "United States of America",
        "countryCode" => 840,
        "location" => nil,
        "dateAddressStandardized" => nil
      }

      # ... other fields omitted for brevity
    }
  }

  @employee_address_payload %{
    "subscriptionId" => 31,
    "timestamp" => "2025-03-28T12:22:49.3790287+00:00",
    "eventName" => "employee.addressupdated",
    "tenantName" => "Whippy",
    "payload" => %{
      "employeeId" => 49_453,
      "address" => %{
        "municipalityId" => nil,
        "county" => nil,
        "countyId" => nil,
        "schoolDistrict" => nil,
        "schoolDistrictId" => nil,
        "schoolJurisId" => nil,
        "pSDCode" => nil,
        "attentionTo" => nil,
        "street1" => "str",
        "street2" => "B2 200",
        "municipality" => nil,
        "region" => "CA",
        "postalCode" => nil,
        "country" => "United States of America",
        "countryCode" => 840,
        "location" => nil,
        "dateAddressStandardized" => nil
      },
      "isTemporaryMailingAddressActive" => false,
      "temporaryMailingAddress" => %{
        "attentionTo" => nil,
        "street1" => nil,
        "street2" => nil,
        "municipality" => nil,
        "region" => nil,
        "postalCode" => nil,
        "country" => nil,
        "countryCode" => nil,
        "location" => nil,
        "dateAddressStandardized" => nil
      }
    }
  }

  @employee_custom_property_payload %{
    "subscriptionId" => 32,
    "timestamp" => "2025-04-03T09:30:02.6013965+00:00",
    "eventName" => "employee.custompropertyupdated",
    "tenantName" => "Whippy",
    "payload" => %{
      "employeeId" => 49_453,
      "propertyValues" => [
        %{
          "propertyDefinitionId" => "5aca1d7d-5f26-4d05-a682-e15fb4ff1655",
          "propertyValue" => "2025-02-05T00:00:00",
          "propertyName" => "Whippy Date 1"
        }
      ]
    }
  }

  @create_assignment_payload %{
    "subscriptionId" => 34,
    "timestamp" => "2025-04-07T10:53:59.5006376+00:00",
    "eventName" => "assignment.created",
    "tenantName" => "Whippy",
    "payload" => %{
      "assignmentId" => 1361,
      "employeeId" => 41_459,
      "jobOrderId" => 543,
      "customerId" => 236,
      "alternateAssignmentId" => nil,
      "temporaryPhoneNumber" => nil,
      "assignmentStatusId" => 3,
      "assignmentStatus" => "Customer Cancelled",
      "activeStatus" => 0,
      "replacesAssignmentId" => nil,
      "customerHasBlacklistedEmployee" => false,
      "employeeHasBlacklistedCustomer" => false,
      "jobTitleId" => 1,
      "jobTitle" => "Default",
      "startDate" => "2024-04-24T00:00:00",
      "originalStartDate" => "2024-04-24T00:00:00",
      "expectedEndDate" => nil,
      "endDate" => "2024-09-05T00:00:00",
      "payRate" => 0,
      "billRate" => 0,
      "employerId" => 1016,
      "companyId" => 1016,
      "doNotAutoClose" => false,
      "serviceRepId" => 1080,
      "accountManagerServiceRepId" => nil,
      "createdByServiceRepId" => 1080,
      "dateCreated" => "2024-04-24T09:39:00",
      "salesTeamId" => 0,
      "branchId" => 1030,
      "performanceNote" => nil
    }
  }

  @create_job_order_payload %{
    "subscriptionId" => 36,
    "timestamp" => "2025-04-07T10:53:59.5006376+00:00",
    "eventName" => "joborder.created",
    "tenantName" => "Whippy",
    "payload" => %{
      "worksiteId" => 0,
      "jobOrderId" => 0,
      "branchId" => 0,
      "jobOrderTypeId" => 0,
      "jobTitleId" => 0,
      "jobTitle" => nil,
      "jobDescription" => nil,
      "payRate" => nil,
      "billRate" => nil,
      "jobOrderStatusId" => 0,
      "isActive" => false,
      "positionsRequired" => 0,
      "positionsFilled" => 0,
      "customerId" => 0,
      "jobOrderDurationId" => 0,
      "dateOrderTaken" => "0001-01-01T00:00:00",
      "startDate" => nil,
      "supervisorContactId" => nil,
      "doNotAutoClose" => false,
      "usesTimeClock" => false,
      "usesPeopleNet" => false,
      "notes" => nil,
      "alternateJobOrderId" => nil,
      "dressCode" => nil,
      "safetyNotes" => nil,
      "directions" => nil,
      "serviceRepId" => 0,
      "salesTeamId" => 0,
      "publicJobTitle" => nil,
      "publicPostingDate" => nil,
      "doNotPostPublicly" => false,
      "publicJobDescriptionContentType" => nil,
      "publicEducationSummary" => nil,
      "publicExperienceSummary" => nil,
      "showPayRate" => false,
      "showWorksiteAddress" => false,
      "isDirectHireJobOrder" => false,
      "localizedJobOrderDetails" => nil,
      "remoteWorkStatusId" => nil,
      "remoteWorkStatus" => nil
    }
  }

  @contact_created_payload %{
    "subscriptionId" => 35,
    "timestamp" => "2025-04-07T10:53:59.5006376+00:00",
    "eventName" => "contact.created",
    "tenantName" => "Whippy",
    "payload" => %{
      "contactId" => 56,
      "firstName" => "Joen",
      "lastName" => "Doe",
      "title" => nil,
      "nickname" => nil,
      "honorific" => nil,
      "birthday" => nil,
      "customerId" => nil,
      "dateCreated" => nil,
      "note" => nil,
      "contactStatusId" => nil,
      "isActive" => false,
      "branchId" => 0,
      "address" => nil,
      "worksiteId" => nil,
      "howHeardOfId" => nil,
      "companyId" => nil,
      "companyTypeId" => nil,
      "serviceRepId" => 0,
      "employeeId" => nil
    }
  }

  @contact_updated_payload %{
    "subscriptionId" => 35,
    "timestamp" => "2025-04-07T10:53:59.5006376+00:00",
    "eventName" => "contact.updated",
    "tenantName" => "Whippy",
    "payload" => %{
      "contactId" => 56,
      "firstName" => "Bunny",
      "lastName" => "Test",
      "title" => nil,
      "nickname" => nil,
      "honorific" => nil,
      "birthday" => nil,
      "customerId" => nil,
      "dateCreated" => nil,
      "note" => nil,
      "contactStatusId" => nil,
      "isActive" => false,
      "branchId" => 0,
      "address" => nil,
      "worksiteId" => nil,
      "howHeardOfId" => nil,
      "companyId" => nil,
      "companyTypeId" => nil,
      "serviceRepId" => 0,
      "employeeId" => nil
    }
  }

  @contact_custom_property_payload %{
    "subscriptionId" => 37,
    "timestamp" => "2025-04-03T09:30:02.6013965+00:00",
    "eventName" => "contact.custompropertyupdated",
    "tenantName" => "Whippy",
    "payload" => %{
      "contactId" => 56,
      "propertyValues" => [
        %{
          "propertyDefinitionId" => "5aca1d7d-5f26-4d05-a682-e15fb4ff1655",
          "propertyValue" => "2025-02-05T00:00:00",
          "propertyName" => "Whippy Date 1"
        }
      ]
    }
  }

  @contact_address_payload %{
    "subscriptionId" => 38,
    "timestamp" => "2025-03-28T12:22:49.3790287+00:00",
    "eventName" => "contact.addressupdated",
    "tenantName" => "Whippy",
    "payload" => %{
      "contactId" => 56,
      "address" => %{
        "municipalityId" => nil,
        "county" => nil,
        "countyId" => nil,
        "schoolDistrict" => nil,
        "schoolDistrictId" => nil,
        "schoolJurisId" => nil,
        "pSDCode" => nil,
        "attentionTo" => nil,
        "street1" => "str",
        "street2" => "B2 200",
        "municipality" => nil,
        "region" => "CA",
        "postalCode" => nil,
        "country" => "United States of America",
        "countryCode" => 840,
        "location" => nil,
        "dateAddressStandardized" => nil
      },
      "isTemporaryMailingAddressActive" => false,
      "temporaryMailingAddress" => %{
        "attentionTo" => nil,
        "street1" => nil,
        "street2" => nil,
        "municipality" => nil,
        "region" => nil,
        "postalCode" => nil,
        "country" => nil,
        "countryCode" => nil,
        "location" => nil,
        "dateAddressStandardized" => nil
      }
    }
  }

  @customer_created_payload %{
    "subscriptionId" => 39,
    "timestamp" => "2025-03-26T15:58:36.0943424+00:00",
    "eventName" => "customer.created",
    "tenantName" => "Whippy",
    "payload" => %{
      "customerId" => 1234,
      "customerName" => nil,
      "departmentName" => nil,
      "parentCustomerId" => nil,
      "rootCustomerId" => 0,
      "branchId" => 0,
      "customerStatusId" => nil,
      "website" => nil,
      "isActive" => false,
      "dateActivated" => "0001-01-01T00:00:00",
      "address" => nil,
      "billingAddress" => nil,
      "worksiteId" => nil,
      "note" => nil,
      "nationalIndustryClassificationSystemCode" => nil
    }
  }

  @customer_custom_property_payload %{
    "subscriptionId" => 40,
    "timestamp" => "2025-04-03T09:30:02.6013965+00:00",
    "eventName" => "customer.custompropertyupdated",
    "tenantName" => "Whippy",
    "payload" => %{
      "customerId" => 1234,
      "propertyValues" => [
        %{
          "propertyDefinitionId" => "5aca1d7d-5f26-4d05-a682-e15fb4ff1655",
          "propertyValue" => "2025-02-05T00:00:00",
          "propertyName" => "Whippy Date 1"
        }
      ]
    }
  }

  setup do
    integration =
      insert(:integration,
        integration: "tempworks",
        client: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "access_token" => "TEST_TOKEN_HERE_0A36D3DC1-1",
          "acr_values" => "tenant:whippy pid:0SOME-DEF-VALUE-BBBB-788888872FA4",
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "whippy-dev",
          "client_secret" => "21secret1heref8be8ce829910",
          "scope" => "assignment-write contact-write customer-write",
          "expires_in" => 3600,
          "token_expires_at" => DateTime.utc_now() |> DateTime.add(36_000, :second) |> DateTime.to_unix()
        },
        settings: %{
          "webhooks" => [
            %{"subscription_id" => nil, "topic" => "employee.created"},
            %{"subscription_id" => nil, "topic" => "employee.updated"},
            %{"subscription_id" => nil, "topic" => "joborder.created"},
            %{"subscription_id" => nil, "topic" => "contact.created"},
            %{"subscription_id" => nil, "topic" => "contact.updated"},
            %{"subscription_id" => nil, "topic" => "customer.created"}
          ]
        }
      )

    contact =
      insert(:contact,
        integration: integration,
        external_organization_id: "test_external_organization_id",
        whippy_contact_id: "123",
        external_contact_id: "49453",
        name: "Bunny - Test",
        phone: "+923330671784"
      )

    temp_contact =
      insert(:contact,
        integration: integration,
        external_organization_id: "test_external_organization_id",
        whippy_contact_id: "12345",
        external_contact_id: "contact-56",
        name: "Joen Doe",
        phone: "+923330672333"
      )

    custom_object =
      insert(:custom_object,
        integration: integration,
        whippy_organization_id: integration.whippy_organization_id,
        whippy_custom_object_id: "123",
        external_entity_type: "employee"
      )

    insert(:custom_object,
      integration: integration,
      whippy_organization_id: integration.whippy_organization_id,
      whippy_custom_object_id: "123",
      external_entity_type: "assignment"
    )

    insert(:custom_object,
      integration: integration,
      whippy_organization_id: integration.whippy_organization_id,
      whippy_custom_object_id: "1234",
      external_entity_type: "job_orders"
    )

    insert(:custom_object,
      integration: integration,
      whippy_organization_id: integration.whippy_organization_id,
      whippy_custom_object_id: "12345",
      external_entity_type: "tempworks_contacts"
    )

    insert(:custom_object,
      integration: integration,
      whippy_organization_id: integration.whippy_organization_id,
      whippy_custom_object_id: "1234",
      external_entity_type: "customers"
    )

    %{
      integration: integration,
      contact: contact,
      tempwork_contact: temp_contact,
      custom_object: custom_object
    }
  end

  describe "maybe_subscribe_to_webhooks/1" do
    test "successfully subscribes new webhook topics", %{integration: integration} do
      with_mocks [
        {Clients.Tempworks, [], list_subscriptions_success_mocks()},
        {Clients.Tempworks, [], subscribe_topic_success_mocks()}
      ] do
        {:ok, updated_integration} = Tempworks.maybe_subscribe_to_webhooks(integration)

        assert updated_integration.settings["webhooks"] == [
                 %{"topic" => "employee.created", "subscription_id" => 456},
                 %{"topic" => "employee.updated", "subscription_id" => 456},
                 %{"topic" => "joborder.created", "subscription_id" => 456},
                 %{"topic" => "contact.created", "subscription_id" => 456},
                 %{"topic" => "contact.updated", "subscription_id" => 456},
                 %{"topic" => "customer.created", "subscription_id" => 456}
               ]
      end
    end

    test "handles error when listing subscriptions fails", %{integration: integration} do
      with_mocks [
        {Clients.Tempworks, [], list_subscriptions_error_mocks()}
      ] do
        assert {:error, "API Error"} =
                 Tempworks.maybe_subscribe_to_webhooks(integration)
      end
    end

    test "handles error when subscribing topic fails", %{integration: integration} do
      with_mocks [
        {Authentication.Tempworks, [], token_mocks()},
        {Clients.Tempworks, [], list_subscriptions_success_mocks()},
        {Clients.Tempworks, [], subscribe_topic_error_mocks()}
      ] do
        {:ok, updated_integration} = Tempworks.maybe_subscribe_to_webhooks(integration)

        assert updated_integration.settings["webhooks"] == [
                 %{"topic" => "employee.created", "subscription_id" => nil, "error" => "Subscription failed"},
                 %{"topic" => "employee.updated", "subscription_id" => nil, "error" => "Subscription failed"},
                 %{"topic" => "joborder.created", "subscription_id" => nil, "error" => "Subscription failed"},
                 %{"topic" => "contact.created", "subscription_id" => nil, "error" => "Subscription failed"},
                 %{"topic" => "contact.updated", "subscription_id" => nil, "error" => "Subscription failed"},
                 %{"topic" => "customer.created", "subscription_id" => nil, "error" => "Subscription failed"}
               ]
      end
    end

    test "returns error for integration without webhooks settings" do
      integration_without_webhooks = insert(:integration, settings: %{})

      assert {:error, "No webhooks configured in integration settings: %{}"} =
               Tempworks.maybe_subscribe_to_webhooks(integration_without_webhooks)
    end

    test "returns error for invalid integration" do
      assert {:error, "Invalid integration struct provided"} =
               Tempworks.maybe_subscribe_to_webhooks(%{invalid: "struct"})
    end
  end

  describe "process_event/2 create employee" do
    test "successfully processes employee update webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]},
        {HTTPoison, [], get_employee_detail_mock()}
      ]) do
        nil = Repo.get_by(Contact, external_contact_id: "49_454")

        payload =
          @employee_update_payload
          |> Map.update("payload", %{}, fn payload ->
            Map.merge(payload, %{"employeeId" => 49_454, "primaryPhoneNumber" => "+923330671785"})
          end)
          |> Map.put("eventName", "employee.created")

        assert {:ok, :processed} = Tempworks.process_event(payload, "test_whippy_organization_id")
      end
    end

    test "update the contact in contacts table", %{integration: _integration, contact: contact} do
      with_mocks([
        {HTTPoison, [], get_employee_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]}
      ]) do
        payload =
          Map.update(@employee_update_payload, "payload", %{}, fn payload -> Map.put(payload, "employeeId", 123) end)

        assert {:ok, :processed} = Tempworks.process_event(payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, contact.id)
        assert updated_contact.name == "Bunny11 - Test"
      end
    end
  end

  describe "process_event/2 update employee" do
    test "successfully processes employee update webhook event", %{integration: _integration} do
      with_mocks([
        {HTTPoison, [], get_employee_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@employee_update_payload, "test_whippy_organization_id")
      end
    end

    test "update the contact in contacts table", %{integration: _integration, contact: contact} do
      with_mocks([
        {HTTPoison, [], get_employee_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]}
      ]) do
        payload =
          Map.update(@employee_update_payload, "payload", %{}, fn payload -> Map.put(payload, "firstName", "Hassan") end)

        assert {:ok, :processed} = Tempworks.process_event(payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, contact.id)

        assert updated_contact.name == "Bunny11 - Test"
      end
    end
  end

  describe "process_event/2 update employee address" do
    test "successfully processes employee address update webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@employee_address_payload, "test_whippy_organization_id")
      end
    end

    test "update the contact in contacts table", %{integration: _integration, contact: contact} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 123}}} end]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@employee_address_payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, contact.id)
        assert updated_contact.address["country_code"] == 840
        assert updated_contact.address["state"] == "CA"
        assert updated_contact.address["country"] == "United States of America"
        assert updated_contact.address["address_line_one"] == "str"
        assert updated_contact.address["address_line_two"] == "B2 200"
      end
    end
  end

  describe "process_event/2 update custom property" do
    test "successfully processes employee address update webhook event", %{integration: _integration} do
      # TODO: FIX mocks
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} =
                 Tempworks.process_event(@employee_custom_property_payload, "test_whippy_organization_id")
      end
    end
  end

  describe "process_event/2 create assignment" do
    test "successfully processes assignment create webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@create_assignment_payload, "test_whippy_organization_id")
      end
    end
  end

  describe "process_event/2 create job order" do
    test "successfully processes job order create webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@create_job_order_payload, "test_whippy_organization_id")
      end
    end
  end

  describe "process_event/2 create contact" do
    test "successfully processes contact update webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 59}}} end]},
        {HTTPoison, [], get_contact_detail_mock()},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        nil = Repo.get_by(Contact, external_contact_id: "contact-59")

        payload =
          Map.update(@contact_created_payload, "Payload", %{}, fn payload ->
            Map.merge(payload, %{"contactId" => 56, "primaryPhoneNumber" => "+923330672333"})
          end)

        assert {:ok, :processed} = Tempworks.process_event(payload, "test_whippy_organization_id")
      end
    end

    test "update the tempworks contact in contacts table", %{integration: _integration, tempwork_contact: temp_contact} do
      with_mocks([
        {HTTPoison, [], get_contact_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 56}}} end]},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@contact_updated_payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, temp_contact.id)
        assert updated_contact.name == "Joen Doe"
      end
    end
  end

  describe "process_event/2 update contact" do
    test "successfully processes contact update webhook event", %{integration: _integration} do
      with_mocks([
        {HTTPoison, [], get_contact_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 56}}} end]},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@contact_updated_payload, "test_whippy_organization_id")
      end
    end

    test "update the tempworks contact in contacts table", %{integration: _integration, tempwork_contact: temp_contact} do
      with_mocks([
        {HTTPoison, [], get_contact_detail_mock()},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 56}}} end]},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        payload =
          Map.update(@contact_updated_payload, "payload", %{}, fn payload -> Map.put(payload, "firstName", "Bunny") end)

        assert {:ok, :processed} = Tempworks.process_event(payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, temp_contact.id)

        assert updated_contact.name == "Joen Doe"
      end
    end
  end

  describe "process_event/2 update contact address" do
    @tag run: true
    test "successfully processes contact address update webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 56}}} end]},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@contact_address_payload, "test_whippy_organization_id")
      end
    end

    test "update the tempworks contact in contacts table", %{integration: _integration, tempwork_contact: temp_contact} do
      with_mocks([
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => 56}}} end]},
        {HTTPoison, [], get_contact_mock()}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@contact_address_payload, "test_whippy_organization_id")
        updated_contact = Repo.get!(Contact, temp_contact.id)
        assert updated_contact.address["country_code"] == 840
        assert updated_contact.address["state"] == "CA"
        assert updated_contact.address["country"] == "United States of America"
        assert updated_contact.address["address_line_one"] == "str"
        assert updated_contact.address["address_line_two"] == "B2 200"
      end
    end
  end

  describe "process_event/2 update contact custom property" do
    test "successfully processes contact custom property", %{integration: _integration} do
      # TODO: FIX mocks
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} =
                 Tempworks.process_event(@contact_custom_property_payload, "test_whippy_organization_id")
      end
    end
  end

  describe "process_event/2 create customer" do
    test "successfully processes customer create webhook event", %{integration: _integration} do
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} = Tempworks.process_event(@customer_created_payload, "test_whippy_organization_id")
      end
    end
  end

  describe "process_event/2 update customer custom property" do
    test "successfully processes customer custom property", %{integration: _integration} do
      # TODO: FIX mocks
      with_mocks([
        {Sync.Workers.Whippy.Writer, [],
         [
           send_custom_object_records_to_whippy: fn _integration, _custom_object_records ->
             :ok
           end
         ]}
      ]) do
        assert {:ok, :processed} =
                 Tempworks.process_event(@customer_custom_property_payload, "test_whippy_organization_id")
      end
    end
  end

  defp token_mocks, do: [get_or_regenerate_service_token: fn integration -> {:ok, integration} end]
  defp list_subscriptions_success_mocks, do: [list_subscriptions: fn _token -> {:ok, []} end]

  defp list_subscriptions_error_mocks, do: [list_subscriptions: fn _token -> {:error, "API Error"} end]

  defp subscribe_topic_success_mocks, do: [subscribe_topic: fn _token, _body -> {:ok, 456} end]

  defp subscribe_topic_error_mocks, do: [subscribe_topic: fn _token, _body -> {:error, "Subscription failed"} end]

  defp get_employee_detail_mock do
    [
      get: fn _url, _headers -> get_employee_webhook_fixture() end
    ]
  end

  defp get_contact_detail_mock do
    [
      get: fn _url, _headers -> get_contacts_webhook_fixture() end
    ]
  end

  defp get_contact_mock do
    [
      get: fn _url, _headers, _opts -> get_contact_fixture() end
    ]
  end
end
