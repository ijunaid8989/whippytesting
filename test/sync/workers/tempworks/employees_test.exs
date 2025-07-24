defmodule Sync.Workers.Tempworks.EmployeesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Activities.Activity
  alias Sync.Channels.Channel
  alias Sync.Clients.Tempworks
  alias Sync.Clients.Whippy
  alias Sync.Contacts.Contact
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers
  alias Sync.Workers.Tempworks.Employees

  setup do
    integration =
      insert(:integration,
        integration: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "scope" => "test_scope",
          "grant_type" => "client_credentials",
          "access_token" => "existing_valid_token",
          "token_expires_at" => DateTime.to_unix(DateTime.utc_now()) + 600,
          "acr_values" => "tenant:twtest pid:uuid"
        },
        settings: %{
          "use_advance_search" => true
        }
      )

    %{integration: integration}
  end

  setup do
    basic_integration =
      insert(:integration,
        integration: "tempworks",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "whippy_api_key" => "test_whippy_api_key",
          "client_id" => "test_client_id",
          "client_secret" => "test_client_secret",
          "scope" => "test_scope",
          "grant_type" => "client_credentials",
          "access_token" => "existing_valid_token",
          "token_expires_at" => DateTime.to_unix(DateTime.utc_now()) + 600,
          "acr_values" => "tenant:twtest pid:uuid"
        },
        settings: %{
          "use_advance_search" => false
        }
      )

    %{basic_integration: basic_integration}
  end

  describe "daily process/1" do
    test "pulls employees from Tempworks and saves them as contacts", %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        assert [] == Repo.all(Contact)

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_employees_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)
      end
    end

    test "pulls employees from Tempworks and saves them as contacts with external_contact_hash and sync_to_whippy",
         %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_employees_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)

        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == true end)
      end
    end

    test "pulls employees from Tempworks and saves them as contacts with external_contact_hash and sync_to_whippy when contact already exist",
         %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "43760",
            name: nil,
            phone: "+18156818941",
            email: nil,
            external_contact_hash: "DEhztdB8uAE6A4Og1Y5AQFxb1LDZDWs7HHAELFOzBAB=",
            should_sync_to_whippy: false,
            external_contact: %{
              "desiredSalary" => nil,
              "jobTitle" => nil,
              "whippyString1" => nil,
              "howHeardOfWhere" => nil,
              "relocate" => nil,
              "id" => 43_760,
              "otherCompensation" => nil,
              "prenoteSent" => nil,
              "on-sitePin" => nil,
              "interviewedBy" => nil,
              "lastEmployeeStatusModifiedDate" => nil,
              "interviewDate" => nil,
              "i-9IsOnFile" => false,
              "enteredBy" => "whippy-dev",
              "whippyString2" => nil,
              "differentiator" => nil,
              "expireDate" => nil,
              "professionalSummary" => nil,
              "whippyBoolean2" => nil,
              "acaSafeHarborRateOfPay" => nil,
              "offerResponse" => nil,
              "whippyDecimal2" => nil,
              "electronicPayComplete" => "N",
              "whippyInteger1" => nil,
              "activelySeeking" => nil,
              "adminPeriodStartDate" => nil,
              "isAssigned" => false,
              "locationDesired" => nil,
              "howHeardOfDetails" => nil,
              "currentSkillcode" => nil,
              "whippyBoolean1" => nil,
              "relocateWhere" => nil,
              "interestCodes" => nil,
              "interestCodeIds" => nil,
              "numericRating" => 0,
              "city" => nil,
              "routingNumber" => nil,
              "alternateEmployeeId" => nil,
              "insuranceDeadline" => nil,
              "street2" => nil,
              "employeeId" => 43_760,
              "bankName" => nil,
              "anniversaryDate" => nil,
              "jobObjective" => nil,
              "recentLogin" => nil,
              "whippyDatalistString2" => nil,
              "whippyMultivalueString1" => nil,
              "psdcode" => nil,
              "lastEvaluationDate" => nil,
              "fteStatus" => nil,
              "whippyGuid2" => nil,
              "benefitElectDivision" => nil,
              "isActive" => true,
              "desiredSkillcode" => nil,
              "whippyDatetime1" => nil,
              "i-9Expires" => nil,
              "phone" => "+18156818941",
              "hireStatus" => "A",
              "lastName" => nil,
              "firstName" => nil,
              "willingToWork" => nil,
              "whippyDatetime2" => nil,
              "averageHoursPerWeek" => nil,
              "zipCode" => nil,
              "wishList" => nil,
              "stateExchange" => nil,
              "street1" => nil,
              "dateOffered" => nil,
              "whippyInteger2" => nil,
              "govtId" => nil,
              "cellPhone" => nil,
              "webcenterRecentLogin" => nil,
              "whippyDate1" => nil,
              "effectiveInsuranceDate" => nil,
              "buzzRecentLogin" => nil,
              "notes" => nil,
              "currentSalary" => nil,
              "prenoteDisapproved" => nil,
              "whippyMoney2" => nil,
              "declinedReason" => nil,
              "email" => nil,
              "active" => nil,
              "whippyDatalistString1" => nil,
              "isEligible" => nil,
              "whippyTime2" => nil,
              "acaStatus" => nil,
              "dateAvailable" => nil,
              "profession" => nil,
              "whippyDecimal1" => nil,
              "prenoteApproved" => nil,
              "whippyGuid1" => nil,
              "whippyTime1" => nil,
              "washedStatus" => "Familiar",
              "prenoteRequired" => nil,
              "whippyMultivalueString2" => nil,
              "hireDate" => nil,
              "jobOrderType" => "TE",
              "adminPeriodStatus" => nil,
              "staffingSpecialist" => "whippy-dev",
              "declinedDate" => nil,
              "whippyDate2" => nil,
              "hrcenterRecentLogin" => nil,
              "activationDate" => "2024-05-21T06:14:00",
              "state" => "CA",
              "resumeOnFile" => false,
              "lastMessageDate" => "2024-05-21T13:57:00",
              "branch" => "WhippyDemoBranch",
              "whippyMoney1" => nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_employees_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)

        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == true end)
        assert Enum.all?(contacts, fn contact -> contact.name == "Joen Doe" end)
        assert Enum.all?(contacts, fn contact -> contact.email == "johndoe@example.com" end)
      end
    end

    test "pulls employees from Tempworks and saves them as contacts with external_contact_hash and sync_to_whippy when contact is new",
         %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        assert [] == Repo.all(Contact)
        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_employees_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)

        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == true end)
      end
    end

    test "pulls employees from Tempworks and update activities table where external_contact_id is nil",
         %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            external_contact_id: "12",
            name: nil,
            phone: "+18156818941",
            email: nil,
            external_contact_hash: "AM3C5WIqlhOfCHEEZcozn1teO5Ui7s5EHueTgHiyix0=",
            should_sync_to_whippy: false,
            external_contact: %{
              "desiredSalary" => nil,
              "jobTitle" => nil,
              "whippyString1" => nil,
              "howHeardOfWhere" => nil,
              "relocate" => nil,
              "id" => 1234,
              "otherCompensation" => nil,
              "prenoteSent" => nil,
              "on-sitePin" => nil,
              "interviewedBy" => nil,
              "lastEmployeeStatusModifiedDate" => nil,
              "interviewDate" => nil,
              "i-9IsOnFile" => false,
              "enteredBy" => "whippy-dev",
              "whippyString2" => nil,
              "differentiator" => nil,
              "expireDate" => nil,
              "professionalSummary" => nil,
              "whippyBoolean2" => nil,
              "acaSafeHarborRateOfPay" => nil,
              "offerResponse" => nil,
              "whippyDecimal2" => nil,
              "electronicPayComplete" => "N",
              "whippyInteger1" => nil,
              "activelySeeking" => nil,
              "adminPeriodStartDate" => nil,
              "isAssigned" => false,
              "locationDesired" => nil,
              "howHeardOfDetails" => nil,
              "currentSkillcode" => nil,
              "whippyBoolean1" => nil,
              "relocateWhere" => nil,
              "interestCodes" => nil,
              "interestCodeIds" => nil,
              "numericRating" => 0,
              "city" => nil,
              "routingNumber" => nil,
              "alternateEmployeeId" => nil,
              "insuranceDeadline" => nil,
              "street2" => nil,
              "employeeId" => 43_760,
              "bankName" => nil,
              "anniversaryDate" => nil,
              "jobObjective" => nil,
              "recentLogin" => nil,
              "whippyDatalistString2" => nil,
              "whippyMultivalueString1" => nil,
              "psdcode" => nil,
              "lastEvaluationDate" => nil,
              "fteStatus" => nil,
              "whippyGuid2" => nil,
              "benefitElectDivision" => nil,
              "isActive" => true,
              "desiredSkillcode" => nil,
              "whippyDatetime1" => nil,
              "i-9Expires" => nil,
              "phone" => "+18156818941",
              "hireStatus" => "A",
              "lastName" => nil,
              "firstName" => nil,
              "willingToWork" => nil,
              "whippyDatetime2" => nil,
              "averageHoursPerWeek" => nil,
              "zipCode" => nil,
              "wishList" => nil,
              "stateExchange" => nil,
              "street1" => nil,
              "dateOffered" => nil,
              "whippyInteger2" => nil,
              "govtId" => nil,
              "cellPhone" => nil,
              "webcenterRecentLogin" => nil,
              "whippyDate1" => nil,
              "effectiveInsuranceDate" => nil,
              "buzzRecentLogin" => nil,
              "notes" => nil,
              "currentSalary" => nil,
              "prenoteDisapproved" => nil,
              "whippyMoney2" => nil,
              "declinedReason" => nil,
              "email" => nil,
              "active" => nil,
              "whippyDatalistString1" => nil,
              "isEligible" => nil,
              "whippyTime2" => nil,
              "acaStatus" => nil,
              "dateAvailable" => nil,
              "profession" => nil,
              "whippyDecimal1" => nil,
              "prenoteApproved" => nil,
              "whippyGuid1" => nil,
              "whippyTime1" => nil,
              "washedStatus" => "Familiar",
              "prenoteRequired" => nil,
              "whippyMultivalueString2" => nil,
              "hireDate" => nil,
              "jobOrderType" => "TE",
              "adminPeriodStatus" => nil,
              "staffingSpecialist" => "whippy-dev",
              "declinedDate" => nil,
              "whippyDate2" => nil,
              "hrcenterRecentLogin" => nil,
              "activationDate" => "2024-05-21T06:14:00",
              "state" => "CA",
              "resumeOnFile" => false,
              "lastMessageDate" => "2024-05-21T13:57:00",
              "branch" => "WhippyDemoBranch",
              "whippyMoney1" => nil
            }
          )

        insert(:activity,
          integration: integration,
          external_organization_id: "test_external_organization_id",
          external_activity_id: nil,
          whippy_activity_id: Ecto.UUID.generate(),
          whippy_contact_id: "test_whippy_contact_id"
        )

        assert [%Activity{external_contact_id: nil} | _] = Repo.all(Activity)
        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_employees_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert [%Activity{} | _] = activities = Repo.all(Activity)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)

        assert Enum.all?(contacts, fn contact -> contact.name == "Joen Doe" end)
        assert Enum.all?(contacts, fn contact -> contact.email == "johndoe@example.com" end)
        assert Enum.all?(activities, fn activity -> activity.external_contact_id == "12" end)
      end
    end

    test "pulls contacts from Tempworks and saves them as contacts", %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_contacts_list)) do
        assert [] == Repo.all(Contact)

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_contacts_from_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)
      end
    end

    test "pulls contacts from Whippy and saves them as contacts", %{basic_integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_list)) do
        assert [] == Repo.all(Contact)

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_pull_contacts_from_whippy",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.whippy_organization_id == "test_whippy_organization_id"
               end)
      end
    end

    test "pushes Whippy contacts into Tempworks where contact has same phone number but different employee name", %{
      basic_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch =
          insert(:channel,
            integration: integration,
            external_channel_id: "42",
            whippy_channel_id: "42"
          )

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "John Doe",
              email: "some@email.com",
              phone: "+1234567890"
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [
                 %Contact{
                   whippy_contact_id: "test_whippy_contact_id",
                   external_contact_id: "1234"
                 }
                 | _
               ] = Repo.all(Contact)
      end
    end

    # this test case doesn't create new contact in tempworks, As tempworks already have the employee,
    # we are extracting the external_contact_id and update it to sync
    test "pushes Whippy contacts into Tempworks where contact has same phone number and employee name", %{
      basic_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: "Magnet 712",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: "+1234567890"
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "43760"} | _] =
                 Repo.all(Contact)
      end
    end

    test "Advance search must parse employee to contact properly", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        {:ok, %{employees: [contact | _]}} =
          Sync.Clients.Tempworks.list_employees_advance_details("",
            limit: 1,
            offset: 0,
            columns: []
          )

        assert contact.external_contact_id == "43760"
        assert contact.phone == "+17862672753"
        assert contact.name == "Magnet 712"

        assert contact.address == %{
                 state: "CA",
                 address_line_one: nil,
                 address_line_two: nil,
                 city: nil,
                 post_code: nil
               }
      end
    end

    test "Advance search must save the external contact as in camel case format", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success, integration.settings)) do
        {:ok, %{employees: [contact | _]}} =
          Sync.Clients.Tempworks.list_employees_advance_details("",
            limit: 1,
            offset: 0,
            columns: []
          )

        assert contact.external_contact["desiredSalary"] == nil
        assert contact.external_contact["employeeId"] == 43_760
        assert contact.external_contact["numericRating"] == 0
      end
    end

    # different phone number and different employee name
    test "pushes Whippy contacts into Tempworks where contact doesn't exist in tempworks", %{
      basic_integration: integration
    } do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: "+1234567891"
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "1234"} | _] =
                 Repo.all(Contact)
      end
    end

    # when contact name is nil, and tempworks returns data for universalPhone_get,
    # then we are updating sync with employee data where employee is active else first map in the employee list
    test "pushes Whippy contacts into Tempworks where contact name is nil", %{basic_integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_phone_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: nil,
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: "+1234567891"
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "43760"} | _] =
                 Repo.all(Contact)
      end
    end

    test "validate contacts phone number length is less than 7 before pushing into Tempworks" do
      employee_payload = %{
        countryCode: 840,
        lastName: "712",
        firstName: "Magnet",
        primaryPhoneNumber: "+123456",
        branchId: "42",
        primaryEmailAddress: "some@email.com",
        primaryPhoneNumberCountryCallingCode: 1,
        region: nil
      }

      access_token = "existing_valid_token"

      assert {:error, "Invalid phone number length"} =
               Sync.Workers.Tempworks.Writer.get_employees_from_external_integration_using_phone(
                 employee_payload,
                 access_token
               )
    end

    # contact phone number is nil and employee doesn't exist in tempworks but multiple employees has same email id
    test "pushes Whippy contacts into Tempworks where contact doesn't have phone number and contact name doesn't exist in external integration",
         %{basic_integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_email_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "1234"} | _] =
                 Repo.all(Contact)
      end
    end

    # Contact will not be created in tempworks, its just updates the sync with external_contact_id
    test "pushes Whippy contacts into Tempworks where contact doesn't have phone number and contact present in external integration",
         %{basic_integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_email_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: "Magnet 712",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "43760"} | _] =
                 Repo.all(Contact)
      end
    end

    test "pushes Whippy contacts into Tempworks where contact doesn't have phone number and name and contact present in external integration",
         %{basic_integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:tempworks_push)},
        {Sync.Clients.Tempworks, [:passthrough], tempworks_client_universal_email_mock()},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _mapped_branch = insert(:channel, integration: integration, external_channel_id: "42", whippy_channel_id: "42")

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: nil,
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Magnet 712",
              email: "some@email.com",
              phone: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_contacts_to_tempworks",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "43760"} | _] =
                 Repo.all(Contact)
      end
    end

    test "pushes Tempworks employees into Whippy", %{basic_integration: integration} do
      with_mock(
        HTTPoison,
        [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "birth_date" => %{"day" => 8, "month" => 11, "year" => 2024},
            "integration_id" => integration.id,
            "address" => %{
              "address_line_one" => nil,
              "address_line_two" => nil,
              "attention_to" => nil,
              "city" => nil,
              "country" => nil,
              "country_code" => nil,
              "location" => nil,
              "post_code" => nil,
              "state" => nil
            }
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            birth_date: "2024-11-08",
            external_contact: %Tempworks.Model.Employee{
              branch: "WhippyTestbranch",
              isActive: true,
              lastName: "Person",
              firstName: "Cool",
              employeeId: 123,
              isAssigned: false,
              postalCode: nil,
              serviceRep: "whippy-test",
              lastMessage: nil,
              phoneNumber: "+1234567890",
              emailAddress: "coolperson@example.com",
              municipality: nil,
              cellPhoneNumber: nil,
              hasResumeOnFile: false,
              governmentPersonalId: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_employees_to_whippy",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })
      end
    end

    test "pushes Tempworks employees into Whippy and set should_sync_to_whippy to false ", %{
      basic_integration: integration
    } do
      with_mock(
        HTTPoison,
        [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "birth_date" => %{},
            "integration_id" => integration.id,
            "address" => %{
              "address_line_one" => nil,
              "address_line_two" => nil,
              "attention_to" => nil,
              "city" => nil,
              "country" => nil,
              "country_code" => nil,
              "location" => nil,
              "post_code" => nil,
              "state" => nil
            }
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            should_sync_to_whippy: true,
            external_contact: %Tempworks.Model.Employee{
              branch: "WhippyTestbranch",
              isActive: true,
              lastName: "Person",
              firstName: "Cool",
              employeeId: 123,
              isAssigned: false,
              postalCode: nil,
              serviceRep: "whippy-test",
              lastMessage: nil,
              phoneNumber: "+1234567890",
              emailAddress: "coolperson@example.com",
              municipality: nil,
              cellPhoneNumber: nil,
              hasResumeOnFile: false,
              governmentPersonalId: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "daily_push_employees_to_whippy",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == false end)
      end
    end

    # test "Advance search must parse employee to contact properly" do
    #   with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success)) do
    #     {:ok, %{employees: [contact | _]}} =
    #       Sync.Clients.Tempworks.list_employees_advance_details("",
    #         limit: 1,
    #         offset: 0,
    #         columns: []
    #       )

    #     assert contact.external_contact_id == "43760"
    #     assert contact.phone == "+17862672753"
    #     assert contact.name == "Magnet 712"

    #     assert contact.address == %{
    #              state: "CA",
    #              address_line_one: nil,
    #              address_line_two: nil,
    #              city: nil,
    #              post_code: nil
    #            }
    #   end
    # end

    # test "Advance search must save the external contact as in camel case format" do
    #   with_mock(HTTPoison, [], httpoison_mock(:tempworks_list, :success)) do
    #     {:ok, %{employees: [contact | _]}} =
    #       Sync.Clients.Tempworks.list_employees_advance_details("",
    #         limit: 1,
    #         offset: 0,
    #         columns: []
    #       )

    #     assert contact.external_contact["desiredSalary"] == nil
    #     assert contact.external_contact["employeeId"] == 43_760
    #     assert contact.external_contact["numericRating"] == 0
    #   end
    # end
  end

  describe "monthly process/1" do
    test "pulls employees date of birth from Tempworks and update in contacts", %{integration: integration} do
      with_mock(Sync.Clients.Tempworks, [], tempworks_client_employess_eeo_mock()) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+18156818941",
            email: nil,
            should_sync_to_whippy: true,
            birth_date: nil,
            inserted_at: ~U[2024-11-10 12:26:58Z],
            updated_at: ~U[2024-11-10 12:26:58Z],
            external_contact: %Tempworks.Model.Employee{
              branch: "WhippyTestbranch",
              isActive: true,
              lastName: "Person",
              firstName: "Cool",
              employeeId: 123,
              isAssigned: false,
              postalCode: nil,
              serviceRep: "whippy-test",
              lastMessage: nil,
              phoneNumber: "+12345678901",
              emailAddress: "coolperson@example.com",
              municipality: nil,
              cellPhoneNumber: nil,
              hasResumeOnFile: false,
              governmentPersonalId: nil
            }
          )

        if Date.utc_today().day == 13 do
          assert :ok ==
                   perform_job(Employees, %{
                     "type" => "monthly_pull_birthdays_from_tempworks",
                     "integration_id" => integration.id
                   })

          assert [%Contact{} | _] = contacts = Repo.all(Contact)

          assert Enum.all?(contacts, fn contact ->
                   contact.external_organization_id == "test_external_organization_id"
                 end)
        end
      end
    end

    test "push employees date of birth to whippy", %{integration: integration} do
      with_mock(
        HTTPoison,
        [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "birth_date" => %{"day" => 8, "month" => 11, "year" => 2024},
            "integration_id" => integration.id,
            "address" => %{
              "address_line_one" => nil,
              "address_line_two" => nil,
              "attention_to" => nil,
              "city" => nil,
              "country" => nil,
              "country_code" => nil,
              "location" => nil,
              "post_code" => nil,
              "state" => nil
            }
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _tempworks_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            should_sync_to_whippy: true,
            birth_date: "2024-11-08",
            external_contact: %Tempworks.Model.Employee{
              branch: "WhippyTestbranch",
              isActive: true,
              lastName: "Person",
              firstName: "Cool",
              employeeId: 123,
              isAssigned: false,
              postalCode: nil,
              serviceRep: "whippy-test",
              lastMessage: nil,
              phoneNumber: "+1234567890",
              emailAddress: "coolperson@example.com",
              municipality: nil,
              cellPhoneNumber: nil,
              hasResumeOnFile: false,
              governmentPersonalId: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Employees, %{
                   "type" => "monthly_push_birthdays_to_whippy",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })
      end
    end
  end

  defp httpoison_mock(:tempworks_list, type, advance_settings) do
    list_employees_fixture =
      case type do
        :success ->
          if advance_settings["use_advance_search"] do
            Fixtures.TempworksClient.list_advance_employee_fixture()
          else
            Fixtures.TempworksClient.list_employees_fixture()
          end

        :failure ->
          {:ok,
           %HTTPoison.Response{
             status_code: 500,
             body: "Internal Server Error",
             request: %HTTPoison.Request{url: "http://test.com"}
           }}
      end

    [
      get: fn _url, _header, _opts -> list_employees_fixture end,
      post: fn _url, _params, _headers, _opts -> Fixtures.TempworksClient.list_advance_employee_fixture() end
    ]
  end

  defp httpoison_mock(:tempworks_contacts_list) do
    [
      get: fn _url, _header, _opts -> Fixtures.TempworksClient.list_contacts_fixture() end
    ]
  end

  defp httpoison_mock(:tempworks_push) do
    [
      post: fn _url, _params, _headers, _opts ->
        Fixtures.TempworksClient.create_employee_response_fixture()
      end
    ]
  end

  defp httpoison_mock(:whippy_list) do
    [
      request: fn :get, _url, _body, _header, _opts ->
        Fixtures.WhippyClient.list_contacts_fixture()
      end
    ]
  end

  defp whippy_reader_mock do
    [
      get_contact_channel: fn _integration, _contact, _limit, _offset ->
        %Channel{external_channel: %{}, external_channel_id: "42"}
      end
    ]
  end

  def tempworks_client_universal_phone_mock do
    [
      get_employee_universal_phone: fn _, _ ->
        {:ok,
         [
           %Sync.Clients.Tempworks.Model.UniversalPhone{
             employeeId: "43760",
             firstName: "Magnet",
             lastName: "712",
             branchName: "WhippyDemoBranch",
             phoneNumber: "+1234567890",
             phoneType: "Phone",
             isAssigned: false,
             isActive: true,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           },
           %Sync.Clients.Tempworks.Model.UniversalPhone{
             employeeId: "12",
             firstName: "John",
             lastName: "Deo",
             branchName: "WhippyDemoBranch",
             phoneNumber: "234567890",
             phoneType: "Phone",
             isAssigned: false,
             isActive: false,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           },
           %Sync.Clients.Tempworks.Model.UniversalPhone{
             employeeId: "13",
             firstName: "Kale",
             lastName: "Deo",
             branchName: "WhippyDemoBranch",
             phoneNumber: "234567890",
             phoneType: "Phone",
             isAssigned: false,
             isActive: true,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           }
         ]}
      end
    ]
  end

  def tempworks_client_universal_email_mock do
    [
      get_employee_universal_email: fn _, _ ->
        {:ok,
         [
           %Sync.Clients.Tempworks.Model.UniversalEmail{
             employeeId: "43760",
             firstName: "Magnet",
             lastName: "712",
             branchName: "WhippyDemoBranch",
             phoneNumber: "+17862672753",
             isAssigned: false,
             isActive: true,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           },
           %Sync.Clients.Tempworks.Model.UniversalEmail{
             employeeId: "4370",
             firstName: "Mgnet",
             lastName: "72",
             branchName: "WhippyDemoBranch",
             phoneNumber: "+1786262753",
             isAssigned: false,
             isActive: true,
             lastMsg: "Message",
             lastDate: "2024-05-21T13:57:00",
             postalCode: nil,
             eCurrentAssignment: nil
           }
         ]}
      end
    ]
  end

  def tempworks_client_employess_eeo_mock do
    [
      get_employee_eeo: fn _, _ ->
        {:ok,
         %{
           employeeId: 0,
           birthPlace: "string",
           dateEntered: "2024-11-08T10:27:15.529Z",
           dateOfBirth: "2024-11-08T10:27:15.529Z",
           gender: "string",
           genderId: 0,
           i9DateVerified: "2024-11-08T10:27:15.529Z",
           isCitizen: true,
           isDisabled: true,
           isEVerified: true,
           nationality: "string",
           nationalityId: 0,
           veteranStatus: "string",
           veteranStatusId: 0
         }}
      end
    ]
  end
end
