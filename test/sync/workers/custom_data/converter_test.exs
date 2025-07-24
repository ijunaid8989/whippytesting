defmodule Sync.Workers.CustomData.ConverterTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Sync.Factory

  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Workers.CustomData.Converter

  describe "convert_external_resource_to_custom_properties/4" do
    test "converts an Avionte Talent to a list of custom properties" do
      integration = insert(:integration, client: :avionte)

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "talent")

      assert {:ok, transaction_result} =
               Converter.convert_external_resource_to_custom_properties(
                 Sync.Clients.Avionte.Parser,
                 integration,
                 custom_object,
                 %Sync.Clients.Avionte.Model.Talent{}
               )

      custom_properties = transaction_result |> Map.values() |> Enum.reject(&is_nil/1)

      assert Enum.any?(custom_properties, fn property ->
               property.external_custom_property.key == "id"
             end)

      assert Enum.any?(custom_properties, fn property ->
               property.external_custom_property.key == "first_name"
             end)

      assert Enum.any?(custom_properties, fn property ->
               property.external_custom_property.key == "last_name"
             end)

      assert Enum.any?(custom_properties, fn property ->
               property.external_custom_property.key == "representative_user_email"
             end)
    end

    test "returns an error tuple if the parser module does not implement the convert_external_resource_to_custom_properties/3 function" do
      integration = insert(:integration, client: :avionte)

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "talent")

      assert {:error, :function_not_implemented_for_parser_module} =
               Converter.convert_external_resource_to_custom_properties(
                 Sync.Clients.Whippy.Parser,
                 integration,
                 custom_object,
                 %Sync.Clients.Whippy.Model.Contact{}
               )
    end
  end

  describe "convert_external_contacts_to_custom_object_records/3" do
    test "[Avionte] creates custom object record for the external contacts that have not been converted yet" do
      # prepare
      integration =
        insert(:integration,
          integration: "avionte",
          client: :avionte,
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "external_api_key" => "test_avionte_api_key",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret",
            "scope" => "test_scope",
            "grant_type" => "client_credentials",
            "access_token" => "existing_valid_token",
            "token_expires_in" => DateTime.to_unix(DateTime.utc_now()) + 600,
            "tenant" => "apitest",
            "fallback_external_user_id" => "12245"
          }
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "1",
        whippy_organization_id: integration.whippy_organization_id,
        external_organization_id: integration.external_organization_id,
        whippy_contact_id: "1",
        external_contact: %{"id" => "1", "representativeUserEmail" => "some@email.com"}
      )

      custom_object = insert(:custom_object, integration: integration)

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "id", "label" => "ID", "type" => "number"}
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "representative_user_email",
            "label" => "Representative User Email",
            "type" => "string"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one, custom_property_two]
      }

      # act
      [{:ok, %CustomObjectRecord{custom_property_values: values}}] =
        Converter.convert_external_contacts_to_custom_object_records(
          Sync.Clients.Avionte.Parser,
          integration,
          custom_object
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1 end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "some@email.com"
             end)
    end

    test "returns an error tuple if the parser module does not implement the convert_resource_to_custom_object_record/4 function" do
      integration = insert(:integration, client: :avionte)

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "talent")

      assert {:error, :function_not_implemented_for_parser_module} =
               Converter.convert_external_contacts_to_custom_object_records(
                 Sync.Clients.Whippy.Parser,
                 integration,
                 custom_object
               )
    end
  end

  describe "convert_external_resource_to_custom_object_record/3" do
    test "[Aqore] creates custom object record for the external job candidate that have not been converted yet" do
      # prepare
      integration =
        insert(:integration,
          integration: "aqore",
          client: :aqore,
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "external_api_key" => "test_aqore_api_key",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret",
            "access_token" => "existing_valid_token"
          }
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "1000204481",
        whippy_organization_id: integration.whippy_organization_id,
        external_organization_id: integration.external_organization_id,
        whippy_contact_id: "1",
        external_contact: %{"id" => "1", "candidateId" => "1000204481"}
      )

      custom_object = insert(:custom_object, integration: integration)

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "id", "label" => "ID", "type" => "string"}
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "candidate_id",
            "label" => "Candidate Id",
            "type" => "string"
          }
        )

      custom_property_three =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "name",
            "label" => "Name",
            "type" => "string"
          }
        )

      custom_property_four =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "phone",
            "label" => "Phone",
            "type" => "string"
          }
        )

      custom_property_five =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "date_of_birth",
            "label" => "Date Of Birth",
            "type" => "string"
          }
        )

      custom_property_six =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "email",
            "label" => "Email",
            "type" => "string"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [
            custom_property_one,
            custom_property_two,
            custom_property_three,
            custom_property_four,
            custom_property_five,
            custom_property_six
          ]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Aqore.Parser,
          integration,
          custom_object,
          job_candidate_struct()
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1 end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == 1_000_204_481
             end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "MARIE B ELLISON"
             end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == 9_114_175_630
             end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "fuu.teor@uovnp.com"
             end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "2003-10-21"
             end)
    end

    test "[Aqore] creates custom object record for the assignment" do
      # prepare
      integration =
        insert(:integration,
          integration: "aqore",
          client: :aqore,
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "external_api_key" => "test_aqore_api_key",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret",
            "access_token" => "existing_valid_token"
          }
        )

      custom_object = insert(:custom_object, integration: integration)

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "id", "label" => "ID", "type" => "string"}
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "assignment_id",
            "label" => "Assignment Id",
            "type" => "string"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one, custom_property_two]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Aqore.Parser,
          integration,
          custom_object,
          assignment_struct()
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1 end)
      assert Enum.any?(values, fn value -> value.external_custom_property_value == "200_04" end)
    end

    test "creates custom object record for the external contacts when whippy_custom_property is nil " do
      # prepare
      integration =
        insert(:integration,
          integration: "avionte",
          client: :avionte,
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "external_api_key" => "test_avionte_api_key",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret",
            "scope" => "test_scope",
            "grant_type" => "client_credentials",
            "access_token" => "existing_valid_token",
            "token_expires_in" => DateTime.to_unix(DateTime.utc_now()) + 600,
            "tenant" => "apitest",
            "fallback_external_user_id" => "12245"
          }
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "1",
        whippy_organization_id: integration.whippy_organization_id,
        external_organization_id: integration.external_organization_id,
        whippy_contact_id: "1",
        external_contact: %{"id" => "1", "representativeUserEmail" => "some@email.com"}
      )

      custom_object = insert(:custom_object, integration: integration)

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{"key" => "id", "label" => "ID", "type" => "number"}
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: nil
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one, custom_property_two]
      }

      # act
      [{:ok, %CustomObjectRecord{custom_property_values: values}}] =
        Converter.convert_external_contacts_to_custom_object_records(
          Sync.Clients.Avionte.Parser,
          integration,
          custom_object
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1 end)
    end

    test "[Tempworks] creates custom object record for the assignment" do
      # prepare
      integration =
        insert(:integration,
          integration: "tempworks",
          client: "tempworks",
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          settings: %{
            "tempworks_region" => "test_tempworks_region",
            "sync_custom_data" => true,
            "only_active_assignments" => true
          },
          authentication: %{
            "access_token" => "test_access_token",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "client_id",
            "client_secret" => "client_secret",
            "acr_values" => "acr_values",
            "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
        )

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "assignment")

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "employee_id",
            "label" => "Employee ID",
            "type" => "number"
          }
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "assignment_id",
            "label" => "Assignment ID",
            "type" => "number"
          }
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "1",
        whippy_contact_id: "4321",
        external_organization_id: "test_external_organization_id"
      )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one, custom_property_two]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Tempworks.Parser,
          integration,
          custom_object,
          tempworks_assignment_struct()
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1 end)
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 1234 end)
    end

    test "[Tempworks] creates custom object record for the employee detail" do
      # prepare
      integration =
        insert(:integration,
          integration: "tempworks",
          client: "tempworks",
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          settings: %{
            "tempworks_region" => "test_tempworks_region",
            "sync_custom_data" => true,
            "only_active_assignments" => true
          },
          authentication: %{
            "access_token" => "test_access_token",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "client_id",
            "client_secret" => "client_secret",
            "acr_values" => "acr_values",
            "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
        )

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "employee")

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "employee_id",
            "label" => "Employee ID",
            "type" => "number"
          }
        )

      custom_property_two =
        insert(:custom_property,
          custom_object: custom_object,
          integration: integration,
          whippy_custom_property: %{
            "key" => "employee_guid",
            "label" => "Employee Guid",
            "type" => "text"
          }
        )

      insert(:contact,
        integration: integration,
        external_contact_id: "1",
        whippy_contact_id: "4321",
        external_organization_id: "test_external_organization_id"
      )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one, custom_property_two]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Tempworks.Parser,
          integration,
          custom_object,
          tempworks_employee_detail_struct(),
          %{whippy_contact_id: "43211"}
        )

      # assert
      assert Enum.any?(values, fn value -> value.external_custom_property_value == 415_988 end)

      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "12kf8ad9-6313-468a-9b6a-8e616aac4074"
             end)
    end

    test "[Tempworks] creates custom object record for the type decimal custom data" do
      # prepare
      integration =
        insert(:integration,
          integration: "tempworks",
          client: "tempworks",
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "access_token" => "test_access_token",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "client_id",
            "client_secret" => "client_secret",
            "acr_values" => "acr_values",
            "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
        )

      custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data"
        )

      insert(:custom_object_record,
        integration: integration,
        custom_object: custom_object,
        external_custom_object_record_id: "1234"
      )

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          whippy_custom_property: %{
            "key" => "whippy_decimal_1",
            "type" => "text"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Tempworks.Parser,
          integration,
          custom_object,
          tempworks_decimal_custom_data_struct(),
          %{external_resource_id: "1234"}
        )

      # assert
      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == 12.12
             end)
    end

    test "[Tempworks] creates custom object record for the integer type custom data" do
      # prepare
      integration =
        insert(:integration,
          integration: "tempworks",
          client: "tempworks",
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "access_token" => "test_access_token",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "client_id",
            "client_secret" => "client_secret",
            "acr_values" => "acr_values",
            "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
        )

      custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data"
        )

      insert(:custom_object_record,
        integration: integration,
        custom_object: custom_object,
        external_custom_object_record_id: "1234"
      )

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          whippy_custom_property: %{
            "key" => "whippy_integer_2",
            "type" => "number"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Tempworks.Parser,
          integration,
          custom_object,
          tempworks_integer_custom_data_struct(),
          %{external_resource_id: "1234"}
        )

      # assert
      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == 12_424
             end)
    end

    test "[Tempworks] creates custom object record for the string type custom data" do
      # prepare
      integration =
        insert(:integration,
          integration: "tempworks",
          client: "tempworks",
          whippy_organization_id: "test_whippy_organization_id",
          external_organization_id: "test_external_organization_id",
          authentication: %{
            "access_token" => "test_access_token",
            "whippy_api_key" => "test_whippy_api_key",
            "client_id" => "client_id",
            "client_secret" => "client_secret",
            "acr_values" => "acr_values",
            "token_expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
        )

      custom_object =
        insert(:custom_object,
          integration: integration,
          external_entity_type: "employee_custom_data"
        )

      insert(:custom_object_record,
        integration: integration,
        custom_object: custom_object,
        external_custom_object_record_id: "1234"
      )

      custom_property_one =
        insert(:custom_property,
          custom_object: custom_object,
          whippy_custom_property: %{
            "key" => "whippy_string_1",
            "type" => "text"
          }
        )

      custom_object = %{
        custom_object
        | custom_properties: [custom_property_one]
      }

      # act
      {:ok, %CustomObjectRecord{custom_property_values: values}} =
        Converter.convert_external_resource_to_custom_object_record(
          Sync.Clients.Tempworks.Parser,
          integration,
          custom_object,
          tempworks_string_custom_data_struct(),
          %{external_resource_id: "1234"}
        )

      # assert
      assert Enum.any?(values, fn value ->
               value.external_custom_property_value == "option B"
             end)
    end

    test "returns an error tuple if the parser module does not implement the convert_resource_to_custom_object_record/4 function" do
      integration = insert(:integration, client: :avionte)

      custom_object =
        insert(:custom_object, integration: integration, external_entity_type: "talent")

      assert {:error, :function_not_implemented_for_parser_module} =
               Converter.convert_external_contacts_to_custom_object_records(
                 Sync.Clients.Whippy.Parser,
                 integration,
                 custom_object
               )
    end
  end

  defp job_candidate_struct do
    %Sync.Clients.Aqore.Model.JobCandidate{
      id: "1",
      jobCandidateId: "1",
      personId: 1_000_204_481,
      candidateId: "1000204481",
      jobId: "134472",
      entity: "JobCandidate",
      currentEntity: "Employee",
      currentEntityStage: "Employee",
      currentEntityStatus: "Deact",
      jobCandidateStage: "Candidate",
      jobCandidateStatus: "Assigned",
      source: "ZenopleJobPortal",
      jobCandidateDate: "2022-01-18T13:02:00Z",
      dateAdded: "2022-01-18T13:02:00Z",
      previouslyWorkedForThisOrganization: true,
      previouslyWorkedForThisJobPosition: false,
      personRating: "Any",
      candidateRating: "Any",
      priority: 2,
      name: "MARIE B ELLISON",
      phone: "9114175630",
      email: "fuu.teor@uovnp.com",
      dateOfBirth: "2003-10-21",
      address: %{
        "address1" => "819 N Wendover Rd",
        "address2" => nil,
        "city" => "Charlotte",
        "state" => "North Carolina",
        "stateCode" => "NC"
      },
      jobModule: "TempJob",
      skills: [
        %{
          "category" => "Administrative",
          "isValidated" => false,
          "skill" => "Demo - Product",
          "yearOfExperience" => 0.0
        },
        %{
          "category" => "Administrative",
          "isValidated" => false,
          "skill" => "EF Carrying 0 to 25 lbs",
          "yearOfExperience" => 0.0
        },
        %{
          "category" => "Administrative",
          "isValidated" => false,
          "skill" => "EF Carrying 25 to 50 lbs",
          "yearOfExperience" => 0.0
        },
        %{
          "category" => "Administrative",
          "isValidated" => false,
          "skill" => "EF Carrying over 50 lbs",
          "yearOfExperience" => 0.0
        }
      ],
      educationHistory: [],
      workHistory: [
        %{
          "employer" => "White duck taco shop",
          "endDate" => "2021-07-13T00:00:00",
          "endYear" => "2021",
          "endtMonth" => "March",
          "lastPay" => 13.0,
          "startDate" => "2021-03-19T00:00:00",
          "startMonth" => "March",
          "startYear" => "2021",
          "title" => "Employee"
        },
        %{
          "employer" => "Montford Deli",
          "endDate" => "2021-12-01T00:00:00",
          "endYear" => "2021",
          "endtMonth" => "August",
          "lastPay" => 10.0,
          "startDate" => "2021-08-01T00:00:00",
          "startMonth" => "August",
          "startYear" => "2021",
          "title" => "Employee"
        }
      ],
      job: %{
        "assigned" => 1,
        "assignmentInfo" => [
          %{
            "assignmentInfo" => "SmokingDetails",
            "assignmentInfoDescription" => "Smoking Details",
            "assignmentInfoValue" => "no smoking available within the premises",
            "infoId" => 202_577
          }
        ],
        "department" => "1560-CV Assembly",
        "description" =>
          "Assemble new and/or replacement parts by operating intermediate machines and equipment.  Must be able to assemble and complete functional units or complex subassemblies from blue prints. Must be able to work at a fast and accurate pace.    \nPHYSICAL RESPONSIBILITIES:\nWill be lifting, moving up to 25lbs frequently, up to 50lbs on occasion and up to 100lbs rarely.                                                    ESSENTIAL DUTIES: \nSet up assembly equipment by adjusting tools and controls, etc. according to procedures and standards. \nQualify run for first piece approval. \nLoad/unload assembly lines safely by using proper handling equipment. \nOperate equipment to highest production and quality standards. \nMake necessary adjustments and replace tools or parts as required. \nUse hand tools and gages appropriate to the work performed. ",
        "endDate" => "2022-03-23",
        "interviewQuestions" => [],
        "jobId" => 134_472,
        "jobModule" => "TempJob",
        "jobSkills" => [
          %{"category" => "Accounting", "skill" => "Accounts Payable & Receivable"},
          %{"category" => "Accounting", "skill" => "Accounts Payable"}
        ],
        "jobTitle" => "Assembly",
        "organization" => "Critical Systems",
        "organizationId" => 18_719,
        "otPayRate" => 16.5,
        "recruiter" => "FRANK TODD",
        "recruiterEmail" => "tbgj.hzba@ebhdy.net",
        "recruiterPhone" => "9115751108",
        "required" => 1,
        "rtPayRate" => 16.5,
        "salary" => 0.0,
        "shiftEndTime" => "23:00:00",
        "shiftStartTime" => "15:00:00"
      }
    }
  end

  defp assignment_struct do
    %Sync.Clients.Aqore.Model.Assignment{
      id: "1",
      assignmentId: "200_04",
      entityListItemId: 200_047,
      entity: "Assignment",
      candidateId: "999992160",
      organizationId: "20494",
      jobId: "131128",
      overTimePayRate: 18.75,
      overTimeBillRate: 28.13,
      payRate: 12.5,
      billRate: 18.75,
      salary: 0.0,
      shift: "",
      status: "Ended",
      candidateName: "JEANETTE L GALLOWAY",
      organizationName: "Child Support_ACH_TN",
      office: "North Carolina_200001",
      cityState: "Charlotte,North Carolina",
      wcCode: "4829NC",
      assignmentType: "Regular",
      address1: "819 N Wendover Rd",
      address2: "",
      city: "Charlotte",
      state: "North Carolina",
      zipCode: "28211",
      fullAddress: "819 N Wendover Rd Charlotte, NC - 28211",
      startDate: "2020-04-28",
      endDate: "2020-07-26",
      endReason: "RateChange",
      performance: "",
      payPeriod: "Weekly",
      dateAdded: "2020-04-28T00:00:00Z",
      recruiterUserId: "0"
    }
  end

  defp tempworks_assignment_struct do
    %Sync.Clients.Tempworks.Model.EmployeeAssignment{
      assignmentId: 1,
      lastName: "Doe",
      firstName: "John",
      middleName: nil,
      employeePrimaryEmailAddress: "",
      employeePrimaryPhoneNumber: "32324249459",
      employeeId: 1234,
      customerId: 1,
      customerName: "WhippyDemoCustomer",
      departmentName: "WhippyDemoDepartment",
      jobTitle: "WhippyDemoJobTitle",
      payRate: 0,
      billRate: 0,
      startDate: "2024-07-15T16:33:56.124Z",
      endDate: "2024-07-15T16:33:56.124Z",
      branchId: 1030,
      branchName: "WhippyDemoBranch",
      isActive: true,
      isDeleted: false,
      jobOrderId: 1,
      supervisorId: 1,
      supervisor: "WhippyDemoSupervisor",
      supervisorContactInfo: "WhippyDemoSupervisorContactInfo",
      originalStartDate: "2024-07-15T16:33:56.124Z",
      expectedEndDate: "2024-07-15T16:33:56.124Z",
      activeStatus: 0,
      assignmentStatusId: 0,
      assignmentStatus: "string",
      performanceNote: "string",
      isTimeclockOrder: true,
      serviceRep: "some-user"
    }
  end

  defp tempworks_employee_detail_struct do
    %Sync.Clients.Tempworks.Model.EmployeeDetail{
      employeeId: 415_988,
      employeeGuid: "12kf8ad9-6313-468a-9b6a-8e616aac4074",
      branchId: 1030,
      branch: "WhippyDemoBranch",
      hierTypeId: 2,
      hierType: "Entity",
      firstName: "Joen",
      middleName: nil,
      lastName: "Doe",
      namePrefix: nil,
      nameSuffix: nil,
      governmentPersonalId: nil,
      isActive: true,
      activationDate: "2024-04-11T14=>39:00",
      deactivationDate: nil,
      resumeDocumentId: nil,
      resumeFileName: nil,
      isAssigned: false,
      isI9OnFile: false,
      i9ExpirationDate: nil,
      jobTitle: nil,
      note: nil,
      numericRating: 0,
      serviceRepId: 1088,
      serviceRep: "whippy-dev",
      serviceRepChatName: nil,
      serviceRepEmail: nil,
      createdByServiceRepId: 1088,
      createdByServiceRep: "whippy-dev",
      companyId: nil,
      company: nil,
      companyIsVendor: nil,
      alternateEmployeeId: nil,
      employerId: 1016,
      employer: "WhippyDemo",
      driverLicenseNumber: nil,
      driverLicenseState: nil,
      driverLicenseClass: nil,
      driverLicenseExpire: "0001-01-01T00:00:00+00:00",
      primaryPhoneNumberContactMethodId: 5724,
      primaryPhoneNumber: "32324249458",
      primaryPhoneNumberContactMethodTypeId: 5,
      primaryPhoneNumberContactMethodType: "Phone",
      primaryPhoneNumberCountryCallingCode: 1,
      primaryEmailAddressContactMethodId: 5725,
      primaryEmailAddress: "johndoe@example.co",
      primaryEmailAddressContactMethodTypeId: 8,
      primaryEmailAddressContactMethodType: "Email",
      employeeStatusId: "A",
      employeeStatus: "Eligible and Active",
      governmentPersonalIdIsScrubbed: false,
      address: %{
        attentionTo: nil,
        street1: "string",
        street2: "string",
        municipality: "string",
        region: "CA",
        postalCode: nil,
        country: "United States of America",
        countryCode: 840,
        location: nil,
        dateAddressStandardized: nil
      }
    }
  end

  defp tempworks_decimal_custom_data_struct do
    [
      %Sync.Clients.Tempworks.Model.CustomData{
        propertyDefinitionId: "0d2a430b-1d99-4e1a-be50-63b41789bde5",
        propertyName: "Whippy Decimal 1",
        propertyValue: "12.12",
        propertyValueId: nil,
        propertyType: "decimal",
        categoryId: nil,
        categoryName: nil,
        isActive: true,
        isRequired: false,
        isReadOnly: false,
        allowMultipleValues: false,
        hasDatalist: false
      }
    ]
  end

  defp tempworks_integer_custom_data_struct do
    [
      %Sync.Clients.Tempworks.Model.CustomData{
        propertyDefinitionId: "0d2a430b-1d99-4e1a-be50-63b41789bde5",
        propertyName: "Whippy Integer 2",
        propertyValue: "12424",
        propertyValueId: nil,
        propertyType: "integer",
        categoryId: nil,
        categoryName: nil,
        isActive: true,
        isRequired: false,
        isReadOnly: false,
        allowMultipleValues: false,
        hasDatalist: false
      }
    ]
  end

  defp tempworks_string_custom_data_struct do
    [
      %Sync.Clients.Tempworks.Model.CustomData{
        propertyDefinitionId: "0d2a430b-1d99-4e1a-be50-63b41789bde5",
        propertyName: "Whippy String 1",
        propertyValue: "option B",
        propertyValueId: nil,
        propertyType: "string",
        categoryId: nil,
        categoryName: nil,
        isActive: true,
        isRequired: false,
        isReadOnly: false,
        allowMultipleValues: false,
        hasDatalist: false
      }
    ]
  end
end
