defmodule Sync.Fixtures.WhippyClient do
  @moduledoc false

  def list_contacts_fixture do
    body = %{
      "data" => [
        %{
          "blocked" => false,
          "communication_preferences" => [
            %{
              "channel_id" => "1e40c565-cc34-485e-ba6d-cdd209eb4a34",
              "created_at" => "2021-06-22T10:36:07Z",
              "id" => "9a4fe8f8-99b5-4737-9d2b-d23a5fa36d4f",
              "last_campaign_date" => "2022-11-03T19:39:23Z",
              "opt_in" => true,
              "opt_in_date" => "2022-10-01T19:39:23Z",
              "opt_out_date" => "2022-12-08T19:39:23Z",
              "updated_at" => "2021-06-22T10:36:07Z"
            }
          ],
          "contact_tags" => [
            %{
              "contact_id" => "4c9b0b8e-76a7-4b24-aefd-96f4dcd2ccbc",
              "created_at" => "2022-10-01T19:39:23Z",
              "id" => "1f2fe9d0-9d70-4d5d-81b5-a5ba932e02ab",
              "tag" => %{
                "color" => "#00bcd4",
                "created_at" => "2022-10-01T19:39:23Z",
                "created_by" => %{
                  "email" => "user.email@gmail.com",
                  "id" => 1,
                  "name" => "Carl Sagan",
                  "phone" => "+142481208301"
                },
                "id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
                "name" => "lead",
                "organization_id" => "58029745-bb1c-4fd3-9130-554428172ab9",
                "state" => "active",
                "type" => "standard",
                "updated_at" => "2022-10-01T19:39:23Z",
                "updated_by" => %{
                  "email" => "user.email@gmail.com",
                  "id" => 1,
                  "name" => "Carl Sagan",
                  "phone" => "+142481208301"
                }
              },
              "tag_id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
              "updated_at" => "2022-10-01T19:39:23Z"
            }
          ],
          "created_at" => "2021-06-22T07:45:45",
          "email" => nil,
          "first_name" => nil,
          "id" => "4c9b0b8e-76a7-4b24-aefd-96f4dcd2ccbc",
          "last_name" => "Doe",
          "name" => "John",
          "notes" => [
            %{
              "body" => "Sample note.",
              "created_at" => "2022-10-01T19:39:23Z",
              "id" => "9ea542d1-2efa-468a-affc-26a57f24917e",
              "updated_at" => "2022-10-01T19:39:23Z",
              "user" => %{
                "email" => "user.email@gmail.com",
                "id" => 1,
                "name" => "Carl Sagan",
                "phone" => "+142481208301"
              }
            }
          ],
          "phone" => "+141756480961",
          "state" => "open",
          "updated_at" => "2021-06-22T07:45:45"
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def create_contact_fixture do
    body = %{
      "data" => %{
        "address" => %{
          "address_line_one" => "1234 Main St",
          "address_line_two" => "Apt 101",
          "city" => "Anytown",
          "country" => "US",
          "postal_code" => "12345",
          "state" => "NY"
        },
        "birth_date" => %{
          "day" => 1,
          "month" => 1,
          "year" => 1990
        },
        "blocked" => false,
        "communication_preferences" => [
          %{
            "channel_id" => "282557b3-bc8d-4f82-a2c8-7d116704d3ba",
            "created_at" => "2021-06-22T10:36:07Z",
            "id" => "ecd1df51-d4f1-4ebc-a749-268f80c5ffb1",
            "last_campaign_date" => "2022-11-03T19:39:23Z",
            "opt_in" => true,
            "opt_in_date" => "2022-10-01T19:39:23Z",
            "opt_out_date" => "2022-12-08T19:39:23Z",
            "updated_at" => "2021-06-22T10:36:07Z"
          }
        ],
        "contact_tags" => [
          %{
            "contact_id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
            "created_at" => "2022-10-01T19:39:23Z",
            "id" => "ff244f50-2f61-4d3e-a5b6-87655da5b1d9",
            "tag" => %{
              "color" => "#00bcd4",
              "created_at" => "2022-10-01T19:39:23Z",
              "created_by" => %{
                "email" => "user.email@gmail.com",
                "id" => 1,
                "name" => "Carl Sagan",
                "phone" => "+142481208301"
              },
              "id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
              "name" => "lead",
              "organization_id" => "1fbbc3e1-c593-4913-b415-f865ad09d806",
              "state" => "active",
              "type" => "standard",
              "updated_at" => "2022-10-01T19:39:23Z",
              "updated_by" => %{
                "email" => "user.email@gmail.com",
                "id" => 1,
                "name" => "Carl Sagan",
                "phone" => "+142481208301"
              }
            },
            "tag_id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
            "updated_at" => "2022-10-01T19:39:23Z"
          }
        ],
        "conversations" => [
          %{
            "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
            "assigned_user_id" => 1,
            "channel_id" => "eb6ec37b-0703-4c4c-a71c-1d5eec3f267d",
            "channel_type" => "phone",
            "contact_id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
            "contact_language" => "es",
            "created_at" => "2021-06-22T07:45:45",
            "id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
            "language" => "en",
            "last_message_date" => "2021-06-22T07:45:45",
            "status" => "open",
            "unread_count" => 3,
            "updated_at" => "2021-06-22T07:45:45"
          },
          %{
            "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
            "assigned_user_id" => 1,
            "channel_id" => "aceac55e-0342-4413-8bde-ca20e5104026",
            "channel_type" => "phone",
            "contact_id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
            "contact_language" => "es",
            "created_at" => "2021-06-22T07:45:45",
            "id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
            "language" => "en",
            "last_message_date" => "2021-06-22T07:45:45",
            "status" => "open",
            "unread_count" => 3,
            "updated_at" => "2021-06-22T07:45:45"
          }
        ],
        "created_at" => "2021-06-22T07:45:45",
        "email" => "johndoe@example.com",
        "external_id" => "fca6902b-4747-4908-9ebe-f8166ca0d640",
        "first_name" => "John",
        "id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
        "last_name" => "doe",
        "name" => "John Doe",
        "notes" => [
          %{
            "body" => "Sample note.",
            "created_at" => "2022-10-01T19:39:23Z",
            "id" => "610042c8-3ff8-40d5-b347-4e2c6ef3ffac",
            "updated_at" => "2022-10-01T19:39:23Z",
            "user" => %{
              "email" => "user.email@gmail.com",
              "id" => 1,
              "name" => "Carl Sagan",
              "phone" => "+142481208301"
            }
          }
        ],
        "phone" => "+14155552671",
        "state" => "open",
        "updated_at" => "2021-06-22T07:45:45"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def list_users_fixture do
    body = %{
      "data" => [
        %{
          "attachment" => nil,
          "channels" => [
            %{
              "address" => "Test Company",
              "id" => "bbe0732b-9742-4582-9867-870c24be51a7",
              "name" => "Location-1",
              "phone" => "+14252607569",
              "state" => "enabled",
              "type" => "phone"
            }
          ],
          "email" => "test@example.com",
          "id" => 12,
          "name" => "Name-1",
          "phone" => "+14288888888",
          "role" => "admin",
          "state" => "enabled"
        },
        %{
          "attachment" => nil,
          "email" => "test2@example.com",
          "channels" => [],
          "id" => 123,
          "name" => "Name-2",
          "phone" => "+14277777777",
          "role" => "admin",
          "state" => "enabled"
        }
      ],
      "total" => 2
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_contact_users_fixture do
    body = %{
      "data" => [
        %{
          "attachment" => nil,
          "email" => "test2@example.com",
          "channels" => [],
          "id" => 456,
          "name" => "Name-2",
          "phone" => "+14277777777",
          "role" => "admin",
          "state" => "enabled"
        }
      ],
      "total" => 2
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_conversations_fixture do
    body = %{
      "data" => [
        %{
          "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
          "assigned_user_id" => 1,
          "channel_id" => "16da312f-69c0-42a3-bf6f-291325389c3b",
          "channel_type" => "phone",
          "contact_id" => "24e6057f-55d9-44e6-b164-29e0882c8ad2",
          "contact_language" => "es",
          "created_at" => "2021-06-22T07:45:45",
          "id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
          "language" => "en",
          "last_message_date" => "2021-06-22T07:45:45",
          "status" => "open",
          "unread_count" => 3,
          "updated_at" => "2021-06-22T07:45:45"
        },
        %{
          "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
          "assigned_user_id" => 1,
          "channel_id" => "7e5de539-25d9-4b1b-b83f-fd7bc918a38e",
          "channel_type" => "phone",
          "contact_id" => "fb8db6e1-5c11-44d4-b623-8df92e8e25ce",
          "contact_language" => "es",
          "created_at" => "2021-06-22T07:45:45",
          "id" => "0ba4f325-6488-4d14-b926-49deb743881a",
          "language" => "en",
          "last_message_date" => "2021-06-22T07:45:45",
          "status" => "open",
          "unread_count" => 3,
          "updated_at" => "2021-06-22T07:45:45"
        }
      ],
      "total" => 2
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_contact_conversations_fixture do
    body = %{
      "data" => [
        %{
          "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
          "assigned_user_id" => 1,
          "channel_id" => "7e5de539-25d9-4b1b-b83f-fd7bc918a38e",
          "channel_type" => "phone",
          "contact_id" => "fb8db6e1-5c11-44d4-b623-8df92e8e25ce",
          "contact_language" => "es",
          "created_at" => "2021-06-22T07:45:45",
          "id" => "0ba4f325-6488-4d14-b926-49deb743881a",
          "language" => "en",
          "last_message_date" => "2021-06-22T07:45:45",
          "status" => "open",
          "unread_count" => 3,
          "updated_at" => "2021-06-22T07:45:45"
        }
      ],
      "total" => 1
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_conversation_fixture do
    body = %{
      "data" => [
        %{
          "assigned_team_id" => "0003c6fe-e469-4e59-8a73-be8ce58f6d53",
          "assigned_user_id" => 1,
          "channel_id" => "16da312f-69c0-42a3-bf6f-291325389c3b",
          "channel_type" => "phone",
          "contact_id" => "24e6057f-55d9-44e6-b164-29e0882c8ad2",
          "contact_language" => "es",
          "created_at" => "2021-06-22T07:45:45",
          "id" => "70c5c186-107e-4122-ba5c-24ac072f5898",
          "language" => "en",
          "last_message_date" => "2021-06-22T07:45:45",
          "status" => "open",
          "unread_count" => 3,
          "updated_at" => "2021-06-22T07:45:45"
        }
      ],
      "total" => 1
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  # By default it returns a conversation with 5 older messages in the span of a couple of days
  # and 5 newer messages (from today)
  @spec get_conversation_fixture(
          :messages_from_today_and_before
          | :messages_from_today
          | :messages_from_before
          | :messages_of_type_call
        ) ::
          {:ok, HTTPoison.Response.t()}
  def get_conversation_fixture(messages_option \\ :messages_from_today_and_before) do
    body = %{
      "data" => %{
        "assigned_team_id" => nil,
        "assigned_user_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "channel_type" => "phone",
        "contact_id" => "24e6057f-55d9-44e6-b164-29e0882c8ad2",
        "contact_language" => "en",
        "created_at" => "2024-03-20T15:14:38.278896Z",
        "id" => "228b38cc-c4e6-4db5-87e8-48a208cc56bd",
        "language" => "en",
        "last_message_date" => "2024-03-20T15:15:47.876105Z",
        "messages" => conversation_messages(messages_option),
        "status" => "closed",
        "unread_count" => 0,
        "updated_at" => "2024-05-31T03:05:11.529423Z"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def get_contact_conversation_fixture(messages_option \\ :messages_from_today_and_before) do
    body = %{
      "data" => %{
        "assigned_team_id" => nil,
        "assigned_user_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "channel_type" => "phone",
        "contact_id" => "fb8db6e1-5c11-44d4-b623-8df92e8e25ce",
        "contact_language" => "en",
        "created_at" => "2024-03-20T15:14:38.278896Z",
        "id" => "228b38cc-c4e6-4db5-87e8-48a208cc56bd",
        "language" => "en",
        "last_message_date" => "2024-03-20T15:15:47.876105Z",
        "messages" => conversation_messages(messages_option),
        "status" => "closed",
        "unread_count" => 0,
        "updated_at" => "2024-05-31T03:05:11.529423Z"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def get_channel_fixture do
    body = %{
      "data" => %{
        "address" => "Test Company",
        "automatic_response_closed" => "We're open now!",
        "automatic_response_open" => "We're closed no!",
        "id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "name" => "Manhattan Office",
        "opening_hours" => [
          %{
            "closes_at" => "22:30",
            "opens_at" => "08:00",
            "state" => "open",
            "weekday" => "Thursday"
          }
        ],
        "phone" => "+195389819491",
        "send_automatic_response_when" => "always",
        "timezone" => "Europe/Dublin",
        "is_hosted_sms" => false,
        "support_ai_agent" => false,
        "color" => "#000000",
        "description" => "Test Description",
        "emoji" => "👨‍👩‍👧‍👦"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_channels_fixture do
    body = %{
      "data" => [
        %{
          "address" => "Test Company",
          "automatic_response_closed" => "We're open now!",
          "automatic_response_open" => "We're closed no!",
          "id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
          "name" => "Manhattan Office",
          "opening_hours" => [
            %{
              "closes_at" => "22:30",
              "opens_at" => "08:00",
              "state" => "open",
              "weekday" => "Thursday"
            }
          ],
          "phone" => "+195389819491",
          "send_automatic_response_when" => "always",
          "timezone" => "Europe/Dublin",
          "is_hosted_sms" => false,
          "support_ai_agent" => false,
          "color" => "#000000",
          "description" => "Test Description",
          "emoji" => "👨‍👩‍👧‍👦"
        }
      ],
      "organization_id" => "1fbbc3e1-c593-4913-b415-f865ad09d806"
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_custom_objects_fixture do
    body = %{
      "data" => [
        %{
          "created_at" => "2023-07-27T14:56:01",
          "custom_properties" => [
            %{
              "created_at" => "2023-07-27T14:56:01",
              "custom_object_id" => "a3b0e0a0-a278-4b29-9386-129967265856",
              "default" => nil,
              "id" => "095c2507-fb20-4f05-b586-ddb54ce77e10",
              "key" => "city",
              "label" => "City",
              "references" => [],
              "required" => false,
              "type" => "text",
              "updated_at" => "2023-07-27T14:56:01"
            }
          ],
          "id" => "a3b0e0a0-a278-4b29-9386-129967265856",
          "key" => "contact_address",
          "label" => "Contact Address",
          "updated_at" => "2023-07-27T14:56:01",
          "emoji" => "👨‍👩‍👧‍👦",
          "description" => "Test Description",
          "color" => "#000000",
          "updated_by" => nil,
          "created_by" => nil
        }
      ],
      "total" => 1
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def create_custom_object_fixture do
    body = %{
      "data" => %{
        "created_at" => "2023-07-27T14:56:01",
        "custom_properties" => [
          %{
            "created_at" => "2023-07-27T14:56:01",
            "custom_object_id" => "a3b0e0a0-a278-4b29-9386-129967265856",
            "default" => nil,
            "id" => "095c2507-fb20-4f05-b586-ddb54ce77e10",
            "key" => "city",
            "label" => "City",
            "references" => [],
            "required" => false,
            "type" => "text",
            "updated_at" => "2023-07-27T14:56:01"
          }
        ],
        "id" => "a3b0e0a0-a278-4b29-9386-129967265856",
        "key" => "contact_address",
        "label" => "Contact Address",
        "updated_at" => "2023-07-27T14:56:01"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def create_custom_property_fixture(attrs \\ %{}) do
    data =
      Map.merge(
        %{
          "created_at" => "2023-07-28T07:07:50",
          "custom_object_id" => "e4d25626-6412-43ed-abf0-692f40485326",
          "default" => "default_value",
          "id" => "9023d008-0451-412f-90da-cb5005617c1a",
          "key" => "custom_property_key",
          "label" => "Custom Property Label",
          "references" => [
            %{
              "custom_object_id" => "e4d25626-6412-43ed-abf0-692f40485326",
              "custom_property_id" => "4f3f2471-cb0c-41a2-88be-63e642181e03",
              "id" => "924ba317-03d4-45f2-b78b-a294fb684d7e",
              "type" => "one_to_many"
            }
          ],
          "required" => false,
          "type" => "text",
          "updated_at" => "2023-07-28T07:07:50"
        },
        attrs
      )

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(%{"data" => data})}}
  end

  def create_custom_object_record_fixture do
    body = %{
      "data" => %{
        "associated_resource_id" => nil,
        "associated_resource_type" => nil,
        "created_at" => "2023-07-28T12:13:45",
        "updated_at" => "2023-07-28T12:13:45",
        "custom_object_id" => "a1736c5c-59ed-473a-9335-0b5bd8726595",
        "id" => "9384c91d-8d7a-43ee-8836-6b212f2650ac",
        "external_id" => "654321",
        "key" => "contact_address",
        "label" => "Contact Address",
        "properties" => %{
          "address" => %{
            "state" => "NY",
            "street" => "123 Main St"
          },
          "city" => "New York",
          "notes" => ["note 1", "note 2"]
        }
      }
    }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def update_custom_object_record_fixture do
    body = %{
      "data" => %{
        "associated_resource_id" => "cc6a752a-fa41-43d8-901a-1bedd59b1816",
        "associated_resource_type" => "contact",
        "created_at" => "2023-07-28T12:13:45",
        "updated_at" => "2023-07-28T12:13:45",
        "custom_object_id" => "a1736c5c-59ed-473a-9335-0b5bd8726595",
        "id" => "9384c91d-8d7a-43ee-8836-6b212f2650ac",
        "external_id" => "123456",
        "key" => "contact_address",
        "label" => "Contact Address",
        "properties" => %{
          "city" => "New York"
        },
        "custom_property_values" => [
          %{
            "id" => "f1b3b1b4-1b3b-4b1b-8b3b-1b3b1b3b1b3b",
            "created_at" => "2023-07-28T12:13:45",
            "custom_object_record_id" => "a1736c5c-59ed-473a-9335-0b5bd8726595",
            "custom_property_id" => "095c2507-fb20-4f05-b586-ddb54ce77e10",
            "value" => "New York",
            "updated_at" => "2023-07-28T12:13:45"
          }
        ]
      }
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  defp conversation_messages(:messages_from_today) do
    today_date = Date.to_string(Date.utc_today())

    [
      %{
        "attachments" => [],
        "body" => "Hello again",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "#{today_date}T13:15:22.021532Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "2f0458bf-3d83-4b55-aeaa-a0e679af57b1",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => "ea3c140f-a78f-481a-8b15-0ac3fdc62b5b",
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-10T15:15:22.021537Z",
        "user_id" => 2
      },
      %{
        "attachments" => [],
        "body" => "Wanted to know if would you like to apply for forklift driver?",
        "campaign_id" => "ee77f868-f96e-48f6-8344-b9bf9c8b0837",
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "#{today_date}T13:14:39.402906Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "612aaaf6-b48a-4dcb-ba18-0e6e4e8aece1",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-10T15:14:39.402908Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "Hello?",
        "campaign_id" => "34af7940-209a-4882-a955-60e6b6702765",
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "#{today_date}T13:14:38.574477Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "0dd2689a-c2b4-4dac-b2da-c40c6ee452f5",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-10T15:14:38.574479Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "The job has been filled. ",
        "campaign_id" => "0dd3fad6-3e56-4460-bb3f-391e02168446",
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "#{today_date}T13:14:38.279237Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "456f14aa-cbea-4a51-be3e-b45460a536c8",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-10T15:14:38.279239Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "Hi there, you haven't answered back.",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "#{today_date}T13:15:47.876105Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "7b80e85b-27cd-4c82-af10-5849ece72258",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => "79e571ca-342b-44d9-90e5-1e1eaf49feee",
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-09T15:15:47.876109Z",
        "user_id" => nil
      }
    ]
  end

  defp conversation_messages(:messages_from_before) do
    [
      %{
        "attachments" => [],
        "body" => "Are you still interested?",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "2024-06-09T15:15:26.918477Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "b27ef765-dc2e-44e5-8eb2-59ab359f3b96",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => "01bed97b-67b0-4a1b-8058-fa41372c4092",
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-09T15:15:26.918480Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "Yes this is us. How can we help?",
        "campaign_id" => "324bbad3-a677-4636-bb69-1ac676e71ad2",
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => nil,
        "created_at" => "2024-06-08T15:14:38.316500Z",
        "delivery_status" => "delivered",
        "direction" => "OUTBOUND",
        "from" => "+14232934393",
        "id" => "c0e48f6a-3711-4472-985e-5b0a2801d385",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+19298016470",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-08T15:14:38.316502Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "I'm interested in a position ",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => "0baa7e9e-c3cc-4c43-aec2-8eb246fbbc40",
        "created_at" => "2024-06-08T15:14:38.286088Z",
        "delivery_status" => "webhook_delivered",
        "direction" => "INBOUND",
        "from" => "+19298016470",
        "id" => "c241269a-07ce-45be-9dd9-b9144ec479e2",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+14232934393",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-08T15:14:38.286090Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "Hi is this staffing 101?",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => "4fe118dc-fa7c-47ec-afab-eb89bcf8041c",
        "created_at" => "2024-06-07T15:15:26.995835Z",
        "delivery_status" => "webhook_delivered",
        "direction" => "INBOUND",
        "from" => "+19298016470",
        "id" => "e2e529e0-f3f7-43f7-9f32-8265c23b8b44",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => "8743e0cb-dca8-47a2-a8c5-a2273092c687",
        "step_id" => nil,
        "to" => "+14232934393",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-07T15:15:26.995837Z",
        "user_id" => nil
      },
      %{
        "attachments" => [],
        "body" => "I saw your job post on some website.com.",
        "campaign_id" => nil,
        "channel_id" => "a8041052-64c5-4dab-b421-dc918f2e4968",
        "contact_id" => "88136cdb-c6ed-4312-b316-49bf50b1d6c8",
        "created_at" => "2024-06-07T15:14:38.327009Z",
        "delivery_status" => "webhook_delivered",
        "direction" => "INBOUND",
        "from" => "+19298016470",
        "id" => "f779c6ea-6530-4daa-9567-0e34c7e6e2ac",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+14232934393",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-06-07T15:14:38.327011Z",
        "user_id" => nil
      }
    ]
  end

  defp conversation_messages(:messages_from_today_and_before) do
    conversation_messages(:messages_from_today) ++ conversation_messages(:messages_from_before)
  end

  defp conversation_messages(:messages_of_type_call) do
    [
      %{
        "attachments" => [
          %{
            "content_type" => "application/json",
            "url" =>
              "https://dashboard-api-prod.s3.amazonaws.com/organization_60f9ee8c-aea1-4860-8b4b-7cf89fa12ddb/calls/9fe83fb0-f9a0-4056-8410-1d20bfb70cb1/analysis.json"
          },
          %{
            "content_type" => "audio/x-wav",
            "url" =>
              "https://dashboard-api-prod.s3.amazonaws.com/organization_60f9ee8c-aea1-4860-8b4b-7cf89fa12ddb/calls/96bc9b0f-4f82-4363-a3ac-6c8bb147a8b4/recording.wav"
          },
          %{
            "content_type" => "application/json",
            "url" =>
              "https://dashboard-api-prod.s3.amazonaws.com/organization_60f9ee8c-aea1-4860-8b4b-7cf89fa12ddb/calls/8a2e7fc5-d858-48d5-b60a-80b2fbb47144/transcript.json"
          }
        ],
        "body" =>
          "Agent: Hey, this is Alex at Express Employment can I have you full name please?\nUser: Uh, yes. John Kennedy.\nAgent: Great, thanks John. Can you please provide me with your current address, including the city, state, and zip code?\nUser: Hey. Los Angeles, California 90025.\nAgent: Thanks for that, John. What is your preferred method of contact - phone call, SMS, or email?\nUser: SMS, please.\nAgent: How did you hear about Express Employment, John?\nUser: Alright. Thank you, Anad. Indeed, Job?\nAgent: Got it, Anad. Can you tell me about your current situation? Are you currently working, and if so, where were you last employed?\nUser: No. I wasn't. I'm not working, and I've never employed before in my life.\nAgent: Thanks for sharing that, Anad. Let's move on to your work history. Starting with your most recent \nUser: My name's my name's John.\nAgent: Apologies for that, John. Let's start with your most recent work history. What was the company name?\nUser: McDonald's.\nAgent: Where is the McDonald's located where you worked, John?\nUser: After going\nAgent: I'm sorry, John, I didn't catch that. Can you please provide the location of the McDonald's where you worked?\nUser: I have to go now.\nAgent: Sure, John. If you have to go, feel free to reach out to us when you're ready to continue. Have a great day!\nUser: Bye.\nAgent: Goodbye, John. Take care!\n",
        "campaign_id" => nil,
        "channel_id" => "0e973d8e-c6f3-45ee-a51e-3b91bfc0f693",
        "contact_id" => "979f90a8-da4b-4dd5-932c-3d702a3e2fe1",
        "created_at" => "2024-07-05T17:25:19.094338Z",
        "delivery_status" => "call_completed",
        "direction" => "INBOUND",
        "from" => "+18054104042",
        "id" => "07707015-04df-45a2-bfb3-c2fddabdfa4f",
        "language" => nil,
        "sequence_id" => nil,
        "step_contact_id" => nil,
        "step_id" => nil,
        "to" => "+15076323028",
        "translated_body" => nil,
        "translation_language" => nil,
        "updated_at" => "2024-07-05T17:26:55.339575Z",
        "user_id" => nil
      }
    ]
  end

  def get_contact_fixture do
    body = %{
      "data" => %{
        "blocked" => false,
        "communication_preferences" => [
          %{
            "channel_id" => "1e40c565-cc34-485e-ba6d-cdd209eb4a34",
            "created_at" => "2021-06-22T10:36:07Z",
            "id" => "9a4fe8f8-99b5-4737-9d2b-d23a5fa36d4f",
            "last_campaign_date" => "2022-11-03T19:39:23Z",
            "opt_in" => true,
            "opt_in_date" => "2022-10-01T19:39:23Z",
            "opt_out_date" => "2022-12-08T19:39:23Z",
            "updated_at" => "2021-06-22T10:36:07Z"
          }
        ],
        "contact_tags" => [
          %{
            "contact_id" => "24e6057f-55d9-44e6-b164-29e0882c8ad2",
            "created_at" => "2025-02-25T15:15:47Z",
            "id" => "1f2fe9d0-9d70-4d5d-81b5-a5ba932e02ab",
            "tag" => %{
              "color" => "#00bcd4",
              "created_at" => "2025-02-25T15:15:47Z",
              "created_by" => %{
                "phone" => "+142481208301"
              },
              "id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
              "name" => "lead",
              "organization_id" => "58029745-bb1c-4fd3-9130-554428172ab9",
              "state" => "active",
              "type" => "standard",
              "updated_at" => "2025-02-25T15:15:47Z",
              "updated_by" => %{
                "phone" => "+142481208301"
              }
            },
            "tag_id" => "b41d3a52-b3dd-4aba-9983-5c3fde6774cc",
            "updated_at" => "2025-02-25T15:15:47Z"
          }
        ],
        "created_at" => "2021-06-22T07:45:45",
        "email" => nil,
        "first_name" => nil,
        "id" => "24e6057f-55d9-44e6-b164-29e0882c8ad2",
        "notes" => [
          %{
            "body" => "Sample note.",
            "created_at" => "2025-02-25T15:15:47Z",
            "id" => "9ea542d1-2efa-468a-affc-26a57f24917e",
            "updated_at" => "2025-02-25T15:15:47Z",
            "user" => %{
              "phone" => "+142481208301"
            }
          }
        ],
        "phone" => "+141756480961",
        "state" => "open",
        "updated_at" => "2025-02-25T15:15:47Z"
      }
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end
end
