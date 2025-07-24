defmodule Sync.Workers.Crelate.ContactsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Channels.Channel
  alias Sync.Clients.Crelate
  alias Sync.Clients.Whippy
  alias Sync.Contacts.Contact
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers
  alias Sync.Workers.Crelate.Entities

  setup do
    integration =
      insert(:integration,
        integration: "Crelate",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "whippy_api_key" => "test_whippy_api_key",
          "external_api_key" => "sx9fgdr8c7gn4tdpyds1fmfybo"
        },
        settings: %{
          "sync_custom_data" => false,
          "only_active_assignments" => false,
          "send_contacts_to_external_integrations" => true,
          "use_production_url" => false
        }
      )

    %{integration: integration}
  end

  describe "daily process/1" do
    test "pulls daily contacts from Crelate and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:contacts_list, :success)) do
        assert [] == Repo.all(Contact)

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Entities, %{
                   "day" => iso_day,
                   "integration_id" => integration.id,
                   "type" => "daily_pull_contacts_from_crelate"
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)
      end
    end

    test "pulls contacts from Whippy and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_list)) do
        assert [] == Repo.all(Contact)

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Entities, %{
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

    test "push Whippy contacts to Crelate and update id in contacts", %{integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:crelate_daily_push)},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
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
                 perform_job(Entities, %{
                   "type" => "daily_push_contacts_to_crelate",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.whippy_organization_id == "test_whippy_organization_id"
               end)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_contact_id == "450bf96e-eb32-42bc-d11f-6ce89035dd08"
               end)
      end
    end

    test "pushes crelate contacts into Whippy", %{integration: integration} do
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
            "address" => %{},
            "integration_id" => integration.id
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _crelate_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            birth_date: "2024-11-08T10:27:15.529Z",
            should_sync_to_whippy: true,
            external_contact: %Crelate.Model.Contact{
              Websites_Other: nil,
              PhoneNumbers_Work_Main: nil,
              LastActionDate: "2024-12-31T12:57:00.58Z",
              InstantAddresses_FacebookChat: nil,
              Websites_Blog: nil,
              UserId: nil,
              PhoneNumbers_Skype: nil,
              UpdatedById: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              EmailAddresses_Work: nil,
              Salutation: %{
                Id: "5bbf075b-d085-4f3f-b39e-a07500b61016",
                Title: "Mr."
              },
              ModifiedOn: "2025-01-07T14:07:38.28Z",
              PhoneNumbers_Fax: nil,
              PhoneNumbers_Home: nil,
              PhoneNumbers_Mobile_Other: nil,
              GenderId: nil,
              InstantAddresses_GoogleTalk: nil,
              InstantAddresses_AIM: nil,
              PhoneNumbers_Work_Direct: nil,
              Tags: nil,
              EmailAddresses_Other_Alternate: nil,
              InstantAddresses_ICQ: nil,
              PrimaryDocumentAttachmentId: nil,
              InstantAddresses_Skype: nil,
              AccountId: nil,
              KeyDates_Birthday: %{
                Id: "f904f446-92c4-46a9-509e-c049112fdd08",
                IsPrimary: true,
                Value: "2005-03-07T00:00:00"
              },
              Websites_Business: nil,
              Addresses_Business: nil,
              TwitterName: nil,
              Owners: [
                %{
                  Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                  IsPrimary: true,
                  Title: "Supriya"
                }
              ],
              RelatedContacts_Spouse: nil,
              CreatedOn: "2024-12-31T08:40:49.35Z",
              PhoneNumbers_Work_Other: nil,
              EntityStatus: 1,
              SalaryDetails: nil,
              Websites_Personal: nil,
              Websites_LinkedIn: nil,
              LastEnrichmentDate: nil,
              DesiredSalaryMax: nil,
              InstantAddresses_Yahoo_Msg: nil,
              NickName: nil,
              LastEngagementDate: "2019-08-24T14:15:22Z",
              SuffixId: %{
                Id: "3e80bad7-efd0-4c25-4f80-7dde951edd08",
                Title: "DDS"
              },
              SpokenTo: nil,
              EthnicityId: nil,
              PreferredContactMethodTypeId: %{
                Id: "98f23b88-e2a7-4e77-4f80-7dde951edd08",
                Title: "Phone"
              },
              ExternalPrimaryKey: nil,
              PhoneNumbers_Other: nil,
              RelatedContacts_Assistant: nil,
              MiddleName: nil,
              RecordType: 1,
              EmailAddresses_Work_Other: nil,
              CreatedById: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              Id: "d637819a-21f0-4ca9-5236-edd37629dd08",
              KeyDates_Anniversary: nil,
              PhoneNumbers_Mobile: %{
                Extension: "+1",
                Id: "ba8ea24d-d15c-4603-115a-efd37629dd08",
                IsPrimary: true,
                Value: "+12345678901"
              },
              LatestPinnedNote: nil,
              JobTypeIds: nil,
              LastName: "user",
              RelatedContacts_OtherContact: nil,
              Websites_GitHub: nil,
              RelatedContacts_ReferredBy: nil,
              EmailAddresses_Personal_Other: nil,
              StatusReason: nil,
              Salary: nil,
              Websites_Other_Alternate: nil,
              KeyDates_Other: nil,
              LastActivityOrModifiedOn: "2025-01-07T14:07:38.28Z",
              IconAttachmentId: nil,
              PhoneNumbers_Potential: nil,
              EmailAddresses_Personal: %{
                Id: "0f9d3f72-92ad-4cdb-cb82-eed37629dd08",
                IsPrimary: true,
                Value: "testuser@whippy.co"
              },
              LastReachOutBy: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              DesiredSalaryMin: nil,
              LastReachOutDate: "2019-08-24T14:15:22Z",
              LastActivityRegardingId: %{
                Id: "60ce123d-b59c-4ac1-b8e1-0f048129dd08",
                Title: nil
              },
              Websites_Quora: nil,
              Websites_Facebook: nil,
              EmailAddresses_Potential: nil,
              Websites_Portfolio: nil,
              Addresses_Home: %{
                City: "Texas City",
                CountryId: %{
                  Id: "7eb08bbf-b0e7-4934-a8c1-a38f00bb19ea",
                  Title: "United States"
                },
                Id: "c11dcd87-253f-4434-82bc-e71b122fdd08",
                IsPrimary: true,
                Line1: "224, new road",
                Location: %{Lat: 29.397, Lon: -94.9203},
                State: "TX",
                ZipCode: "77590"
              },
              Education: nil,
              CurrentPosition: nil,
              Name: "user, Test",
              ContactSourceId: nil,
              FirstName: "Test",
              Addresses_Other: nil,
              PhoneNumbers_Other_Alternate: nil,
              InstantAddresses_Other: nil,
              InstantAddresses_FaceTime: nil,
              InstantAddresses_Twitter: nil,
              LastActivityDate: "2024-12-31T12:57:00.58Z",
              EmailAddresses_Other: nil,
              ContactNum: 1,
              Description: nil,
              Websites_RSSFeed: nil,
              ContactNumber: nil
            }
          )

        iso_day = Date.to_iso8601(Date.utc_today())

        assert :ok ==
                 perform_job(Entities, %{
                   "type" => "daily_push_contacts_to_whippy",
                   "integration_id" => integration.id,
                   "day" => iso_day
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == false end)
      end
    end
  end

  describe "full sync process/1" do
    test "pulls contacts from Crelate and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:contacts_list, :success)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Entities, %{
                   "integration_id" => integration.id,
                   "type" => "pull_contacts_from_crelate"
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id"
               end)
      end
    end

    test "push Whippy contacts to Crelate in bulk and update id in contacts", %{integration: integration} do
      with_mocks([
        {HTTPoison, [], httpoison_mock(:crelate_bulk_push)},
        {Workers.Whippy.Reader, [], whippy_reader_mock()}
      ]) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "John max",
              email: "johnsome@email.com",
              phone: "+1230067890"
            }
          )

        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: "test user1",
            phone: "+12345677700",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "test user1",
              email: "someone@email.com",
              phone: "+12345677700"
            }
          )

        assert :ok ==
                 perform_job(Entities, %{
                   "type" => "push_contacts_to_crelate",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.whippy_organization_id == "test_whippy_organization_id"
               end)
      end
    end

    test "pushes crelate contacts into Whippy in full sync", %{integration: integration} do
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
            "address" => %{},
            "integration_id" => integration.id
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _crelate_employee =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            birth_date: "2024-11-08T10:27:15.529Z",
            should_sync_to_whippy: true,
            external_contact: %Crelate.Model.Contact{
              Websites_Other: nil,
              PhoneNumbers_Work_Main: nil,
              LastActionDate: "2024-12-31T12:57:00.58Z",
              InstantAddresses_FacebookChat: nil,
              Websites_Blog: nil,
              UserId: nil,
              PhoneNumbers_Skype: nil,
              UpdatedById: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              EmailAddresses_Work: nil,
              Salutation: %{
                Id: "5bbf075b-d085-4f3f-b39e-a07500b61016",
                Title: "Mr."
              },
              ModifiedOn: "2025-01-07T14:07:38.28Z",
              PhoneNumbers_Fax: nil,
              PhoneNumbers_Home: nil,
              PhoneNumbers_Mobile_Other: nil,
              GenderId: nil,
              InstantAddresses_GoogleTalk: nil,
              InstantAddresses_AIM: nil,
              PhoneNumbers_Work_Direct: nil,
              Tags: nil,
              EmailAddresses_Other_Alternate: nil,
              InstantAddresses_ICQ: nil,
              PrimaryDocumentAttachmentId: nil,
              InstantAddresses_Skype: nil,
              AccountId: nil,
              KeyDates_Birthday: %{
                Id: "f904f446-92c4-46a9-509e-c049112fdd08",
                IsPrimary: true,
                Value: "2005-03-07T00:00:00"
              },
              Websites_Business: nil,
              Addresses_Business: nil,
              TwitterName: nil,
              Owners: [
                %{
                  Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                  IsPrimary: true,
                  Title: "Supriya"
                }
              ],
              RelatedContacts_Spouse: nil,
              CreatedOn: "2024-12-31T08:40:49.35Z",
              PhoneNumbers_Work_Other: nil,
              EntityStatus: 1,
              SalaryDetails: nil,
              Websites_Personal: nil,
              Websites_LinkedIn: nil,
              LastEnrichmentDate: nil,
              DesiredSalaryMax: nil,
              InstantAddresses_Yahoo_Msg: nil,
              NickName: nil,
              LastEngagementDate: "2019-08-24T14:15:22Z",
              SuffixId: %{
                Id: "3e80bad7-efd0-4c25-4f80-7dde951edd08",
                Title: "DDS"
              },
              SpokenTo: nil,
              EthnicityId: nil,
              PreferredContactMethodTypeId: %{
                Id: "98f23b88-e2a7-4e77-4f80-7dde951edd08",
                Title: "Phone"
              },
              ExternalPrimaryKey: nil,
              PhoneNumbers_Other: nil,
              RelatedContacts_Assistant: nil,
              MiddleName: nil,
              RecordType: 1,
              EmailAddresses_Work_Other: nil,
              CreatedById: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              Id: "d637819a-21f0-4ca9-5236-edd37629dd08",
              KeyDates_Anniversary: nil,
              PhoneNumbers_Mobile: %{
                Extension: "+1",
                Id: "ba8ea24d-d15c-4603-115a-efd37629dd08",
                IsPrimary: true,
                Value: "+12345678901"
              },
              LatestPinnedNote: nil,
              JobTypeIds: nil,
              LastName: "user",
              RelatedContacts_OtherContact: nil,
              Websites_GitHub: nil,
              RelatedContacts_ReferredBy: nil,
              EmailAddresses_Personal_Other: nil,
              StatusReason: nil,
              Salary: nil,
              Websites_Other_Alternate: nil,
              KeyDates_Other: nil,
              LastActivityOrModifiedOn: "2025-01-07T14:07:38.28Z",
              IconAttachmentId: nil,
              PhoneNumbers_Potential: nil,
              EmailAddresses_Personal: %{
                Id: "0f9d3f72-92ad-4cdb-cb82-eed37629dd08",
                IsPrimary: true,
                Value: "testuser@whippy.co"
              },
              LastReachOutBy: %{
                Id: "2617363a-2a08-4800-102d-1e69cd28dd08",
                Title: "Supriya"
              },
              DesiredSalaryMin: nil,
              LastReachOutDate: "2019-08-24T14:15:22Z",
              LastActivityRegardingId: %{
                Id: "60ce123d-b59c-4ac1-b8e1-0f048129dd08",
                Title: nil
              },
              Websites_Quora: nil,
              Websites_Facebook: nil,
              EmailAddresses_Potential: nil,
              Websites_Portfolio: nil,
              Addresses_Home: %{
                City: "Texas City",
                CountryId: %{
                  Id: "7eb08bbf-b0e7-4934-a8c1-a38f00bb19ea",
                  Title: "United States"
                },
                Id: "c11dcd87-253f-4434-82bc-e71b122fdd08",
                IsPrimary: true,
                Line1: "224, new road",
                Location: %{Lat: 29.397, Lon: -94.9203},
                State: "TX",
                ZipCode: "77590"
              },
              Education: nil,
              CurrentPosition: nil,
              Name: "user, Test",
              ContactSourceId: nil,
              FirstName: "Test",
              Addresses_Other: nil,
              PhoneNumbers_Other_Alternate: nil,
              InstantAddresses_Other: nil,
              InstantAddresses_FaceTime: nil,
              InstantAddresses_Twitter: nil,
              LastActivityDate: "2024-12-31T12:57:00.58Z",
              EmailAddresses_Other: nil,
              ContactNum: 1,
              Description: nil,
              Websites_RSSFeed: nil,
              ContactNumber: nil
            }
          )

        assert :ok ==
                 perform_job(Entities, %{
                   "type" => "push_contacts_to_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == false end)
      end
    end
  end

  defp httpoison_mock(:contacts_list, type) do
    list_contacts_fixture =
      case type do
        :success ->
          Fixtures.CrelateClient.list_contacts_fixture()

        :failure ->
          {:ok,
           %HTTPoison.Response{
             status_code: 500,
             body: "Internal Server Error",
             request: %HTTPoison.Request{url: "http://test.com"}
           }}
      end

    [
      get: fn _url, _headers, _opts -> list_contacts_fixture end
    ]
  end

  defp httpoison_mock(:whippy_list) do
    [
      request: fn :get, _url, _body, _header, _opts ->
        Fixtures.WhippyClient.list_contacts_fixture()
      end
    ]
  end

  defp httpoison_mock(:crelate_daily_push) do
    [
      post: fn _url, _params, _opts ->
        Fixtures.CrelateClient.create_bulk_contacts_response_fixture()
      end
    ]
  end

  defp httpoison_mock(:crelate_bulk_push) do
    [
      post: fn _url, _params, _opts -> Fixtures.CrelateClient.create_bulk_contacts_response_fixture() end
    ]
  end

  defp whippy_reader_mock do
    [
      get_contact_channel: fn _integration, _contact, _limit, _offset ->
        %Channel{external_channel: %{}, external_channel_id: "42"}
      end
    ]
  end
end
