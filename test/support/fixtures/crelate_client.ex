defmodule Sync.Fixtures.CrelateClient do
  @moduledoc false
  def list_contacts_fixture do
    body = %{
      "Data" => [
        %{
          AccountId: nil,
          Addresses_Business: nil,
          Addresses_Home: %{
            "City" => "Texas City",
            "CountryId" => %{
              "Id" => "7eb08bbf-b0e7-4934-a8c1-a38f00bb19ea",
              "Title" => "United States"
            },
            "Id" => "c11dcd87-253f-4434-82bc-e71b122fdd08",
            "IsPrimary" => true,
            "Line1" => "224, new road",
            "Location" => %{"Lat" => 29.397, "Lon" => -94.9203},
            "State" => "TX",
            "ZipCode" => "77590"
          },
          Addresses_Other: nil,
          ContactNum: 1,
          ContactNumber: nil,
          ContactSourceId: nil,
          CreatedById: %{
            "Id" => "2617363a-2a08-4800-102d-1e69cd28dd08",
            "Title" => "Supriya"
          },
          CreatedOn: "2024-12-31T08:40:49.35Z",
          CurrentPosition: nil,
          Description: nil,
          DesiredSalaryMax: nil,
          DesiredSalaryMin: nil,
          Education: nil,
          EmailAddresses_Other: nil,
          EmailAddresses_Other_Alternate: nil,
          EmailAddresses_Personal: %{
            "Id" => "0f9d3f72-92ad-4cdb-cb82-eed37629dd08",
            "IsPrimary" => true,
            "Value" => "testuser@whippy.co"
          },
          EmailAddresses_Personal_Other: nil,
          EmailAddresses_Potential: nil,
          EmailAddresses_Work: nil,
          EmailAddresses_Work_Other: nil,
          EntityStatus: 1,
          EthnicityId: nil,
          ExternalPrimaryKey: nil,
          FirstName: "Test",
          GenderId: nil,
          IconAttachmentId: nil,
          Id: "d637819a-21f0-4ca9-5236-edd37629dd08",
          InstantAddresses_AIM: nil,
          InstantAddresses_FacebookChat: nil,
          InstantAddresses_FaceTime: nil,
          InstantAddresses_GoogleTalk: nil,
          InstantAddresses_ICQ: nil,
          InstantAddresses_Other: nil,
          InstantAddresses_Skype: nil,
          InstantAddresses_Twitter: nil,
          InstantAddresses_Yahoo_Msg: nil,
          JobTypeIds: nil,
          KeyDates_Anniversary: nil,
          KeyDates_Birthday: %{
            "Id" => "f904f446-92c4-46a9-509e-c049112fdd08",
            "IsPrimary" => true,
            "Value" => "2005-03-07T00:00:00"
          },
          KeyDates_Other: nil,
          LastActionDate: "2024-12-31T12:57:00.58Z",
          LastActivityDate: "2024-12-31T12:57:00.58Z",
          LastActivityOrModifiedOn: "2025-01-07T14:07:38.28Z",
          LastActivityRegardingId: %{
            "Id" => "60ce123d-b59c-4ac1-b8e1-0f048129dd08",
            "Title" => nil
          },
          LastEngagementDate: "2019-08-24T14:15:22Z",
          LastEnrichmentDate: nil,
          LastName: "user",
          LastReachOutBy: %{
            "Id" => "2617363a-2a08-4800-102d-1e69cd28dd08",
            "Title" => "Supriya"
          },
          LastReachOutDate: "2019-08-24T14:15:22Z",
          LatestPinnedNote: nil,
          MiddleName: nil,
          ModifiedOn: "2025-01-07T14:07:38.28Z",
          Name: "user, Test",
          NickName: nil,
          Owners: [
            %{
              "Id" => "2617363a-2a08-4800-102d-1e69cd28dd08",
              "IsPrimary" => true,
              "Title" => "Supriya"
            }
          ],
          PhoneNumbers_Fax: nil,
          PhoneNumbers_Home: nil,
          PhoneNumbers_Mobile: %{
            "Extension" => "+1",
            "Id" => "ba8ea24d-d15c-4603-115a-efd37629dd08",
            "IsPrimary" => true,
            "Value" => "+12345678901"
          },
          PhoneNumbers_Mobile_Other: nil,
          PhoneNumbers_Other: nil,
          PhoneNumbers_Other_Alternate: nil,
          PhoneNumbers_Potential: nil,
          PhoneNumbers_Skype: nil,
          PhoneNumbers_Work_Direct: nil,
          PhoneNumbers_Work_Main: nil,
          PhoneNumbers_Work_Other: nil,
          PreferredContactMethodTypeId: %{
            "Id" => "98f23b88-e2a7-4e77-4f80-7dde951edd08",
            "Title" => "Phone"
          },
          PrimaryDocumentAttachmentId: nil,
          RecordType: 1,
          RelatedContacts_Assistant: nil,
          RelatedContacts_OtherContact: nil,
          RelatedContacts_ReferredBy: nil,
          RelatedContacts_Spouse: nil,
          Salary: nil,
          SalaryDetails: nil,
          Salutation: %{
            "Id" => "5bbf075b-d085-4f3f-b39e-a07500b61016",
            "Title" => "Mr."
          },
          SpokenTo: nil,
          StatusReason: nil,
          SuffixId: %{
            "Id" => "3e80bad7-efd0-4c25-4f80-7dde951edd08",
            "Title" => "DDS"
          },
          Tags: nil,
          TwitterName: nil,
          UpdatedById: %{
            "Id" => "2617363a-2a08-4800-102d-1e69cd28dd08",
            "Title" => "Supriya"
          },
          UserId: nil,
          Websites_Blog: nil,
          Websites_Business: nil,
          Websites_Facebook: nil,
          Websites_GitHub: nil,
          Websites_LinkedIn: nil,
          Websites_Other: nil,
          Websites_Other_Alternate: nil,
          Websites_Personal: nil,
          Websites_Portfolio: nil,
          Websites_Quora: nil,
          Websites_RSSFeed: nil
        },
        %{
          AccountId: nil,
          Addresses_Business: nil,
          Addresses_Home: nil,
          Addresses_Other: nil,
          ContactNum: 4,
          ContactNumber: nil,
          ContactSourceId: nil,
          CreatedById: %{
            "Id" => "2617363a-2a08-4800-102d-1e69cd28dd08",
            "Title" => "Supriya"
          },
          CreatedOn: "2024-12-31T10:36:01.79Z",
          CurrentPosition: nil,
          Description: nil,
          DesiredSalaryMax: nil,
          DesiredSalaryMin: nil,
          Education: nil,
          EmailAddresses_Other: nil,
          EmailAddresses_Other_Alternate: nil,
          EmailAddresses_Personal: nil,
          EmailAddresses_Personal_Other: nil,
          EmailAddresses_Potential: nil,
          EmailAddresses_Work: nil,
          EmailAddresses_Work_Other: nil,
          EntityStatus: 1,
          EthnicityId: nil,
          ExternalPrimaryKey: "string",
          FirstName: nil,
          GenderId: nil,
          IconAttachmentId: nil,
          Id: "f14a26a3-296d-45e9-fcac-faeb8629dd08",
          InstantAddresses_AIM: nil,
          InstantAddresses_FacebookChat: nil,
          InstantAddresses_FaceTime: nil,
          InstantAddresses_GoogleTalk: nil,
          InstantAddresses_ICQ: nil,
          InstantAddresses_Other: nil,
          InstantAddresses_Skype: nil,
          InstantAddresses_Twitter: nil,
          InstantAddresses_Yahoo_Msg: nil,
          JobTypeIds: nil,
          KeyDates_Anniversary: nil,
          KeyDates_Birthday: nil,
          KeyDates_Other: nil,
          LastActionDate: nil,
          LastActivityDate: nil,
          LastActivityOrModifiedOn: "2024-12-31T10:36:01.79Z",
          LastActivityRegardingId: nil,
          LastEngagementDate: nil,
          LastEnrichmentDate: nil,
          LastName: nil,
          LastReachOutBy: nil,
          LastReachOutDate: nil,
          LatestPinnedNote: nil,
          MiddleName: nil,
          ModifiedOn: "2024-12-31T10:36:01.79Z",
          Name: "",
          NickName: nil,
          Owners: [
            %{
              "Id" => "38a5a5bb-dc30-49a2-b175-1de0d1488c43",
              "IsPrimary" => true,
              "Title" => nil
            }
          ],
          PhoneNumbers_Fax: nil,
          PhoneNumbers_Home: nil,
          PhoneNumbers_Mobile: nil,
          PhoneNumbers_Mobile_Other: nil,
          PhoneNumbers_Other: nil,
          PhoneNumbers_Other_Alternate: nil,
          PhoneNumbers_Potential: nil,
          PhoneNumbers_Skype: nil,
          PhoneNumbers_Work_Direct: nil,
          PhoneNumbers_Work_Main: nil,
          PhoneNumbers_Work_Other: nil,
          PreferredContactMethodTypeId: nil,
          PrimaryDocumentAttachmentId: nil,
          RecordType: nil,
          RelatedContacts_Assistant: nil,
          RelatedContacts_OtherContact: nil,
          RelatedContacts_ReferredBy: nil,
          RelatedContacts_Spouse: nil,
          Salary: nil,
          SalaryDetails: nil,
          Salutation: nil,
          SpokenTo: nil,
          StatusReason: nil,
          SuffixId: nil,
          Tags: nil,
          TwitterName: nil,
          UpdatedById: nil,
          UserId: nil,
          Websites_Blog: nil,
          Websites_Business: nil,
          Websites_Facebook: nil,
          Websites_GitHub: nil,
          Websites_LinkedIn: nil,
          Websites_Other: nil,
          Websites_Other_Alternate: nil,
          Websites_Personal: nil,
          Websites_Portfolio: nil,
          Websites_Quora: nil,
          Websites_RSSFeed: nil
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def create_contact_fixture(attrs \\ %{}) do
    default =
      %{
        entity: %{
          EmailAddresses_Personal: %{
            IsPrimary: true,
            Value: "some@email.com"
          },
          FirstName: "John",
          LastName: "Doe",
          PhoneNumbers_Mobile: %{
            Extension: "+1",
            IsPrimary: true,
            Value: "234567890"
          }
        }
      }

    Map.merge(default, attrs)
  end

  def create_contact_response_fixture do
    body =
      %{
        "Data" => "450bf96e-eb32-42bc-d11f-6ce89035dd08",
        "Metadata" => %{
          "CorrelationId" => "0a322651-8d7a-43c2-9b00-23a3eaee0a96",
          "TimeStamp" => "2025-01-15T18:17:44.8245878Z",
          "Url" => "https://sandbox.crelate.com/api3/contacts?api_key=sx9fgdr8c7gn4tdpyds1fmfybo",
          "Verb" => "POST",
          "TotalRecords" => nil,
          "MoreRecords" => nil,
          "Links" => nil
        },
        "Errors" => []
      }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def create_bulk_contacts_response_fixture do
    body =
      %{
        "Data" => [
          "450bf96e-eb32-42bc-d11f-6ce89035dd08",
          "c2939903-ad19-4639-b378-85a2b334dd08"
        ],
        "Metadata" => %{
          "CorrelationId" => "0a322651-8d7a-43c2-9b00-23a3eaee0a96",
          "TimeStamp" => "2025-01-15T18:17:44.8245878Z",
          "Url" => "https://sandbox.crelate.com/api3/contacts?api_key=sx9fgdr8c7gn4tdpyds1fmfybo",
          "Verb" => "POST",
          "TotalRecords" => nil,
          "MoreRecords" => nil,
          "Links" => nil
        },
        "Errors" => []
      }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def create_bulk_contacts_fixture(attrs \\ %{}) do
    default =
      %{
        entities: [
          %{
            EmailAddresses_Personal: %{
              IsPrimary: true,
              Value: "johnsome@email.com"
            },
            FirstName: "John",
            LastName: "max",
            PhoneNumbers_Mobile: %{
              Extension: "+1",
              IsPrimary: true,
              Value: "+1230067890"
            }
          },
          %{
            EmailAddresses_Personal: %{
              IsPrimary: true,
              Value: "testuser1@whippy.co"
            },
            FirstName: "test",
            LastName: "user1",
            PhoneNumbers_Mobile: %{
              Extension: "+1",
              IsPrimary: true,
              Value: "2345677700"
            }
          }
        ]
      }

    Map.merge(default, attrs)
  end

  def create_activity_fixture do
    body = %{
      "Data" => "767a9de7-7349-48a2-1ec3-03d1d33bdd08",
      "Metadata" => %{
        "CorrelationId" => "0a322651-8d7a-43c2-9b00-23a3eaee0a96",
        "TimeStamp" => "2025-01-15T18:17:44.8245878Z",
        "Url" => "https://sandbox.crelate.com/api3/contacts?api_key=sx9fgdr8c7gn4tdpyds1fmfybo",
        "Verb" => "POST",
        "TotalRecords" => nil,
        "MoreRecords" => nil,
        "Links" => nil
      },
      "Errors" => []
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end
end
