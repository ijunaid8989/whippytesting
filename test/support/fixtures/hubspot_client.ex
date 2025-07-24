defmodule Sync.Fixtures.HubspotClient do
  @moduledoc false
  alias Sync.Contacts.Contact

  def pull_contacts do
    %{
      "results" => [
        %{
          "id" => "23269232882",
          "properties" => %{
            "createdate" => "2024-07-09T12:07:10.342Z",
            "email" => "emailmaria@hubspot.com",
            "firstname" => "Maria",
            "hs_object_id" => "23269232882",
            "lastmodifieddate" => "2024-07-26T00:55:57.433Z",
            "lastname" => "Johnson (Sample Contact)",
            "phone" => nil
          },
          "createdAt" => "2024-07-09T12:07:10.342Z",
          "updatedAt" => "2024-07-26T00:55:57.433Z",
          "archived" => false
        },
        %{
          "id" => "23270390504",
          "properties" => %{
            "createdate" => "2024-07-09T12:07:10.686Z",
            "email" => "bh@hubspot.com",
            "firstname" => "Brian",
            "hs_object_id" => "23270390504",
            "lastmodifieddate" => "2024-07-31T10:37:25.779Z",
            "lastname" => "Halligan (Sample Contact)",
            "phone" => nil
          },
          "createdAt" => "2024-07-09T12:07:10.686Z",
          "updatedAt" => "2024-07-31T10:37:25.779Z",
          "archived" => false
        },
        %{
          "id" => "26099837165",
          "properties" => %{
            "createdate" => "2024-07-24T17:41:22.895Z",
            "email" => "ahmad+test1@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26099837165",
            "lastmodifieddate" => "2024-07-26T00:54:41.826Z",
            "lastname" => "User1",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-24T17:41:22.895Z",
          "updatedAt" => "2024-07-26T00:54:41.826Z",
          "archived" => false
        },
        %{
          "id" => "26117680372",
          "properties" => %{
            "createdate" => "2024-07-24T19:13:32.914Z",
            "email" => "ahmad+test2@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26117680372",
            "lastmodifieddate" => "2024-07-26T00:52:38.405Z",
            "lastname" => "User2",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-24T19:13:32.914Z",
          "updatedAt" => "2024-07-26T00:52:38.405Z",
          "archived" => false
        },
        %{
          "id" => "26256445664",
          "properties" => %{
            "createdate" => "2024-07-25T14:38:07.625Z",
            "email" => "ahmad+test3@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26256445664",
            "lastmodifieddate" => "2024-07-26T00:53:32.177Z",
            "lastname" => "User3",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-25T14:38:07.625Z",
          "updatedAt" => "2024-07-26T00:53:32.177Z",
          "archived" => false
        }
      ]
    }
  end

  def pull_contacts_paginated do
    %{
      "paging" => %{
        "next" => %{
          "after" => "26256445664"
        }
      },
      "results" => [
        %{
          "id" => "26099837165",
          "properties" => %{
            "createdate" => "2024-07-24T17:41:22.895Z",
            "email" => "ahmad+test1@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26099837165",
            "lastmodifieddate" => "2024-07-26T00:54:41.826Z",
            "lastname" => "User1",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-24T17:41:22.895Z",
          "updatedAt" => "2024-07-26T00:54:41.826Z",
          "archived" => false
        },
        %{
          "id" => "26117680372",
          "properties" => %{
            "createdate" => "2024-07-24T19:13:32.914Z",
            "email" => "ahmad+test2@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26117680372",
            "lastmodifieddate" => "2024-07-26T00:52:38.405Z",
            "lastname" => "User2",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-24T19:13:32.914Z",
          "updatedAt" => "2024-07-26T00:52:38.405Z",
          "archived" => false
        },
        %{
          "id" => "26256445664",
          "properties" => %{
            "createdate" => "2024-07-25T14:38:07.625Z",
            "email" => "ahmad+test3@whippy.co",
            "firstname" => "Test",
            "hs_object_id" => "26256445664",
            "lastmodifieddate" => "2024-07-26T00:53:32.177Z",
            "lastname" => "User3",
            "phone" => "+353879185423"
          },
          "createdAt" => "2024-07-25T14:38:07.625Z",
          "updatedAt" => "2024-07-26T00:53:32.177Z",
          "archived" => false
        }
      ]
    }
  end

  def get_whippy_contacts do
    [
      %Contact{
        name: "Test User4",
        phone: "00004",
        email: "ahmad+test4@whippy.co"
      },
      %Contact{
        name: "Test User4",
        phone: "00004",
        email: "ahmad+test4@whippy.co"
      }
    ]
  end

  def push_contacts do
    %{
      "status" => "COMPLETE",
      "results" => [
        %{
          "id" => "27597545708",
          "properties" => %{
            "createdate" => "2024-08-01T17:31:46.738Z",
            "email" => "ahmad+test4@whippy.co",
            "firstname" => "Test",
            "hs_all_contact_vids" => "27597545708",
            "hs_email_domain" => "whippy.co",
            "hs_is_contact" => "true",
            "hs_is_unworked" => "true",
            "hs_lifecyclestage_lead_date" => "2024-08-01T17:31:46.738Z",
            "hs_marketable_status" => "false",
            "hs_marketable_until_renewal" => "false",
            "hs_membership_has_accessed_private_content" => "0",
            "hs_object_id" => "27597545708",
            "hs_object_source" => "INTEGRATION",
            "hs_object_source_id" => "3579920",
            "hs_object_source_label" => "INTEGRATION",
            "hs_pipeline" => "contacts-lifecycle-pipeline",
            "hs_registered_member" => "0",
            "hs_searchable_calculated_phone_number" => "4",
            "lastmodifieddate" => "2024-08-01T17:31:46.738Z",
            "lastname" => "User4",
            "lifecyclestage" => "lead",
            "phone" => "00004"
          },
          "createdAt" => "2024-08-01T17:31:46.738Z",
          "updatedAt" => "2024-08-01T17:31:46.738Z",
          "archived" => false
        },
        %{
          "id" => "27597545707",
          "properties" => %{
            "createdate" => "2024-08-01T17:31:46.738Z",
            "email" => "ahmad+test5@whippy.co",
            "firstname" => "Test",
            "hs_all_contact_vids" => "27597545707",
            "hs_email_domain" => "whippy.co",
            "hs_is_contact" => "true",
            "hs_is_unworked" => "true",
            "hs_lifecyclestage_lead_date" => "2024-08-01T17:31:46.738Z",
            "hs_marketable_status" => "false",
            "hs_marketable_until_renewal" => "false",
            "hs_membership_has_accessed_private_content" => "0",
            "hs_object_id" => "27597545707",
            "hs_object_source" => "INTEGRATION",
            "hs_object_source_id" => "3579920",
            "hs_object_source_label" => "INTEGRATION",
            "hs_pipeline" => "contacts-lifecycle-pipeline",
            "hs_registered_member" => "0",
            "hs_searchable_calculated_phone_number" => "5",
            "lastmodifieddate" => "2024-08-01T17:31:46.738Z",
            "lastname" => "User5",
            "lifecyclestage" => "lead",
            "phone" => "00005"
          },
          "createdAt" => "2024-08-01T17:31:46.738Z",
          "updatedAt" => "2024-08-01T17:31:46.738Z",
          "archived" => false
        }
      ],
      "startedAt" => "2024-08-01T17:31:46.709Z",
      "completedAt" => "2024-08-01T17:31:46.966Z"
    }
  end

  def get_sms_activities do
    [
      %{
        external_contact_id: "1",
        external_contact_name: "Test User1",
        external_user_id: "1",
        company_id: "1",
        whippy_activity: %{
          "type" => "sms",
          "body" => "test body 1",
          "updated_at" => "2024-08-01T17:31:46.738Z"
        }
      },
      %{
        external_contact_id: "2",
        external_user_id: "2",
        company_id: "1",
        whippy_activity: %{
          "type" => "sms",
          "body" => "test body 2",
          "updated_at" => "2024-08-01T17:31:46.738Z"
        }
      }
    ]
  end

  def get_not_sms_activities do
    [
      %{
        external_contact_id: "1",
        external_contact_name: "Test User1",
        external_user_id: "1",
        company_id: "1",
        whippy_conversation_id: "1",
        whippy_organization_id: "1",
        whippy_activity_id: "1",
        whippy_activity: %{
          "type" => "note",
          "body" => "test body 1",
          "updated_at" => "2024-08-01T17:31:46.738Z"
        }
      },
      %{
        external_contact_id: "2",
        external_contact_name: "Test User2",
        external_user_id: "2",
        company_id: "1",
        whippy_conversation_id: "1",
        whippy_organization_id: "1",
        whippy_activity_id: "2",
        whippy_activity: %{
          "type" => "email",
          "body" => "test body 2",
          "updated_at" => "2024-08-01T17:31:46.738Z"
        }
      },
      %{
        external_contact_id: "3",
        external_contact_name: "Test User3",
        external_user_id: "3",
        whippy_conversation_id: "1",
        whippy_organization_id: "1",
        whippy_activity_id: "3",
        company_id: "1",
        whippy_activity: %{
          "type" => "call",
          "body" => "",
          "updated_at" => "2024-08-01T17:31:46.738Z"
        }
      }
    ]
  end
end
