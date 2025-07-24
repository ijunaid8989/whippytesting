defmodule Sync.Clients.WhippyTest do
  use ExUnit.Case, async: false

  import Mock
  import Sync.Fixtures.WhippyClient

  alias Sync.Clients.Whippy, as: WhippyClient
  alias Sync.Clients.Whippy.Model.Channel

  describe "list_contacts" do
    test "if we pass it a limit, it will be received" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, [limit: 5]}, {:recv_timeout, 30_000}] = opts
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", limit: 5)
      end
    end

    test "if we pass it an offset, it will be received" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, [offset: 50]}, {:recv_timeout, 30_000}] = opts
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", offset: 50)
      end
    end

    test "if we pass it channel ids, it will be displayed as" do
      contact_one_id = Ecto.UUID.generate()
      contact_two_id = Ecto.UUID.generate()

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("channels[][id]"))
          assert Enum.member?(values, contact_one_id)
          assert Enum.member?(values, contact_two_id)
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", channel_ids: [contact_one_id, contact_two_id])
      end
    end

    test "if we pass it channel phones, it will be displayed as" do
      phone_one = "+18188001111"
      phone_two = "+18188002222"

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("channels[][phone]"))
          assert Enum.member?(values, phone_one)
          assert Enum.member?(values, phone_two)
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", channel_phones: [phone_one, phone_two])
      end
    end

    test "if we pass it a phone, it will be filtered" do
      phone = "+18188001111"

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, [phone: "+18188001111"]}, {:recv_timeout, 30_000}] = opts
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", phone: phone)
      end
    end

    test "if we pass it multiple options it will be respected" do
      phone = "+18188001111"
      email = "johndoe@gmail.com"

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, params}, {:recv_timeout, 30_000}] = opts
          assert Keyword.has_key?(params, :phone)
          assert Keyword.has_key?(params, :email)
          list_contacts_fixture()
        end do
        WhippyClient.list_contacts("api_key", phone: phone, email: email)
      end
    end
  end

  describe "get_conversation/2" do
    test "if we pass in a message offset, it gets respected" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, ["messages[offset]": 20]}, {:options, [recv_timeout: 30_000]}] = opts
          get_conversation_fixture()
        end do
        WhippyClient.get_conversation("api_key", Ecto.UUID.generate(), message_offset: 20)
      end
    end

    test "if we pass in a message limit, it gets respected" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [{:params, ["messages[limit]": 5]}, {:options, [recv_timeout: 30_000]}] = opts
          get_conversation_fixture()
        end do
        WhippyClient.get_conversation("api_key", Ecto.UUID.generate(), message_limit: 5)
      end
    end
  end

  describe "get_channel/2" do
    test "correctly parses a whippy channel" do
      with_mock HTTPoison, request: fn _method, _url, _body, _header, _opts -> get_channel_fixture() end do
        assert {:ok, %Channel{}} = WhippyClient.get_channel("api_key", "123")
      end
    end
  end

  describe "list_channels/1" do
    test "correctly parses a list of channels" do
      with_mock HTTPoison, request: fn _method, _url, _body, _header, _opts -> list_channels_fixture() end do
        assert {:ok, %{channels: [%Channel{}]}} = WhippyClient.list_channels("api_key")
      end
    end
  end

  describe "list_conversations/2" do
    test "if you pass in a list of channel ids, it will be respected" do
      id_one = Ecto.UUID.generate()
      id_two = Ecto.UUID.generate()

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("channels[][id]"))
          assert Enum.member?(values, id_one)
          assert Enum.member?(values, id_two)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key", channel_ids: [id_one, id_two])
      end
    end

    test "if you pass in a list of channel phones, it will be respected" do
      phone_one = "+18188001111"
      phone_two = "+18188002222"

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("channels[][phone]"))
          assert Enum.member?(values, phone_one)
          assert Enum.member?(values, phone_two)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key", channel_phones: [phone_one, phone_two])
      end
    end

    test "if you pass in a list of contact phones, it will be respected" do
      phone_one = "+18188001111"
      phone_two = "+18188002222"

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("contacts[][phone]"))
          assert Enum.member?(values, phone_one)
          assert Enum.member?(values, phone_two)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key", contact_phones: [phone_one, phone_two])
      end
    end

    test "if you pass in a list of contact ids, it will be respected" do
      id_one = Ecto.UUID.generate()
      id_two = Ecto.UUID.generate()

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("contacts[][id]"))
          assert Enum.member?(values, id_one)
          assert Enum.member?(values, id_two)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key", contact_ids: [id_one, id_two])
      end
    end

    test "if you pass in a list of assigned user ids, it will be respected" do
      id_one = Ecto.UUID.generate()
      id_two = Ecto.UUID.generate()

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          params = Keyword.get(opts, :params)
          values = Keyword.get_values(params, String.to_atom("assigned_users[]"))
          assert Enum.member?(values, id_one)
          assert Enum.member?(values, id_two)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key", assigned_user_ids: [id_one, id_two])
      end
    end

    test "if you pass in a created_at object, it will be respected" do
      now = DateTime.utc_now()

      three_days_ago = DateTime.add(now, -3, :day)
      seven_days_ago = DateTime.add(now, -7, :day)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          ["created_at[before]": ^seven_days_ago, "created_at[after]": ^three_days_ago] = Keyword.get(opts, :params)
          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key",
          created_at: [before: seven_days_ago, after: three_days_ago]
        )
      end
    end

    test "if you pass in a updated_at object, it will be respected" do
      now = DateTime.utc_now()

      three_days_ago = DateTime.add(now, -3, :day)
      seven_days_ago = DateTime.add(now, -7, :day)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          ["updated_at[before]": ^seven_days_ago, "updated_at[after]": ^three_days_ago] = Keyword.get(opts, :params)

          list_conversations_fixture()
        end do
        WhippyClient.list_conversations("api_key",
          updated_at: [before: seven_days_ago, after: three_days_ago]
        )
      end
    end
  end

  describe "list_custom_objects/2" do
    test "if we pass it a limit, it will be received" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [params: [limit: 5]] = opts
          list_custom_objects_fixture()
        end do
        WhippyClient.list_custom_objects("api_key", limit: 5)
      end
    end

    test "if we pass it an offset, it will be received" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          assert [params: [offset: 50]] = opts
          list_custom_objects_fixture()
        end do
        WhippyClient.list_custom_objects("api_key", offset: 50)
      end
    end

    test "if we pass it multiple options they will be respected" do
      limit = 5
      offset = 50

      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, opts ->
          [params: params] = opts
          assert Keyword.has_key?(params, :limit)
          assert Keyword.has_key?(params, :offset)
          list_custom_objects_fixture()
        end do
        WhippyClient.list_custom_objects("api_key", limit: limit, offset: offset)
      end
    end

    test "returns parsed custom objects and their total count" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, _opts -> list_custom_objects_fixture() end do
        assert {:ok,
                %{
                  total: 1,
                  custom_objects: [
                    %{
                      whippy_custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                      external_entity_type: "contact_address",
                      whippy_custom_object: %Sync.Clients.Whippy.Model.CustomObject{
                        created_at: "2023-07-27T14:56:01",
                        custom_properties: [
                          %Sync.Clients.Whippy.Model.CustomProperty{
                            created_at: "2023-07-27T14:56:01",
                            custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                            default: nil,
                            id: "095c2507-fb20-4f05-b586-ddb54ce77e10",
                            key: "city",
                            label: "City",
                            required: false,
                            type: "text",
                            updated_at: "2023-07-27T14:56:01"
                          }
                        ]
                      },
                      custom_properties: [
                        %{
                          whippy_custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                          whippy_custom_property: %Sync.Clients.Whippy.Model.CustomProperty{
                            created_at: "2023-07-27T14:56:01",
                            custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                            default: nil,
                            id: "095c2507-fb20-4f05-b586-ddb54ce77e10",
                            key: "city",
                            label: "City",
                            required: false,
                            type: "text",
                            updated_at: "2023-07-27T14:56:01"
                          }
                        }
                      ]
                    }
                  ]
                }} =
                 WhippyClient.list_custom_objects("api_key")
      end
    end
  end

  describe "create_custom_object/2" do
    test "returns parsed custom object with parsed custom properties" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, _opts -> create_custom_object_fixture() end do
        assert {:ok,
                %{
                  custom_properties: [
                    %{
                      whippy_custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                      whippy_custom_property: %Sync.Clients.Whippy.Model.CustomProperty{
                        created_at: "2023-07-27T14:56:01",
                        custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                        default: nil,
                        id: "095c2507-fb20-4f05-b586-ddb54ce77e10",
                        key: "city",
                        label: "City",
                        required: false,
                        type: "text",
                        updated_at: "2023-07-27T14:56:01"
                      },
                      whippy_custom_property_id: "095c2507-fb20-4f05-b586-ddb54ce77e10"
                    }
                  ],
                  external_entity_type: "contact_address",
                  whippy_custom_object: %Sync.Clients.Whippy.Model.CustomObject{
                    created_at: "2023-07-27T14:56:01",
                    custom_properties: [
                      %Sync.Clients.Whippy.Model.CustomProperty{
                        created_at: "2023-07-27T14:56:01",
                        custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856",
                        default: nil,
                        id: "095c2507-fb20-4f05-b586-ddb54ce77e10",
                        key: "city",
                        label: "City",
                        required: false,
                        type: "text",
                        updated_at: "2023-07-27T14:56:01"
                      }
                    ],
                    id: "a3b0e0a0-a278-4b29-9386-129967265856",
                    key: "contact_address",
                    label: "Contact Address",
                    updated_at: "2023-07-27T14:56:01"
                  },
                  whippy_custom_object_id: "a3b0e0a0-a278-4b29-9386-129967265856"
                }} =
                 WhippyClient.create_custom_object("api_key", %{})
      end
    end
  end

  describe "create_custom_property/3" do
    test "if we pass in a custom object ID, it will be added to the URL path" do
      with_mock HTTPoison,
        request: fn _method, url, _body, _header, _opts ->
          assert url =~ "v1/custom_objects/123/properties"
          create_custom_property_fixture()
        end do
        WhippyClient.create_custom_property("api_key", "123", %{})
      end
    end

    test "returns parsed custom property" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, _opts -> create_custom_property_fixture() end do
        assert {:ok,
                %{
                  whippy_custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326",
                  whippy_custom_property: %Sync.Clients.Whippy.Model.CustomProperty{
                    created_at: "2023-07-28T07:07:50",
                    custom_object_id: "e4d25626-6412-43ed-abf0-692f40485326",
                    default: "default_value",
                    id: "9023d008-0451-412f-90da-cb5005617c1a",
                    key: "custom_property_key",
                    label: "Custom Property Label",
                    required: false,
                    type: "text",
                    updated_at: "2023-07-28T07:07:50"
                  },
                  whippy_custom_property_id: "9023d008-0451-412f-90da-cb5005617c1a"
                }} =
                 WhippyClient.create_custom_property("api_key", "123", %{})
      end
    end
  end

  describe "create_custom_object_record/3" do
    test "if we pass in a custom object ID, it will be added to the URL path" do
      with_mock HTTPoison,
        request: fn _method, url, _body, _header, _opts ->
          assert url =~ "v1/custom_objects/123/records"
          create_custom_object_record_fixture()
        end do
        WhippyClient.create_custom_object_record("api_key", "123", %{external_id: "876"})
      end
    end

    test "returns parsed custom object record" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, _opts -> create_custom_object_record_fixture() end do
        assert {
                 :ok,
                 %{
                   custom_property_values: [],
                   external_custom_object_record_id: "654321",
                   whippy_custom_object_id: "a1736c5c-59ed-473a-9335-0b5bd8726595",
                   whippy_custom_object_record: %Sync.Clients.Whippy.Model.CustomObjectRecord{
                     associated_resource_id: nil,
                     associated_resource_type: nil,
                     created_at: "2023-07-28T12:13:45",
                     custom_object_id: "a1736c5c-59ed-473a-9335-0b5bd8726595",
                     external_id: "654321",
                     id: "9384c91d-8d7a-43ee-8836-6b212f2650ac",
                     key: "contact_address",
                     label: "Contact Address",
                     properties: %{
                       "address" => %{"state" => "NY", "street" => "123 Main St"},
                       "city" => "New York",
                       "notes" => ["note 1", "note 2"]
                     },
                     updated_at: "2023-07-28T12:13:45"
                   },
                   whippy_custom_object_record_id: "9384c91d-8d7a-43ee-8836-6b212f2650ac"
                 }
               } =
                 WhippyClient.create_custom_object_record("api_key", "123", %{})
      end
    end
  end

  describe "update_custom_object_record/4" do
    test "if we pass in a custom object ID and record ID, they will be added to the URL path" do
      with_mock HTTPoison,
        request: fn _method, url, _body, _header, _opts ->
          assert url =~ "v1/custom_objects/123/records/456"
          update_custom_object_record_fixture()
        end do
        WhippyClient.update_custom_object_record("api_key", "123", "456", %{})
      end
    end

    test "returns parsed custom object record" do
      with_mock HTTPoison,
        request: fn _method, _url, _body, _header, _opts -> update_custom_object_record_fixture() end do
        assert {
                 :ok,
                 %{
                   custom_property_values: [],
                   external_custom_object_record_id: "123456",
                   whippy_custom_object_id: "a1736c5c-59ed-473a-9335-0b5bd8726595",
                   whippy_custom_object_record: %Sync.Clients.Whippy.Model.CustomObjectRecord{
                     associated_resource_id: "cc6a752a-fa41-43d8-901a-1bedd59b1816",
                     associated_resource_type: "contact",
                     created_at: "2023-07-28T12:13:45",
                     custom_object_id: "a1736c5c-59ed-473a-9335-0b5bd8726595",
                     external_id: "123456",
                     id: "9384c91d-8d7a-43ee-8836-6b212f2650ac",
                     key: "contact_address",
                     label: "Contact Address",
                     properties: %{"city" => "New York"},
                     updated_at: "2023-07-28T12:13:45"
                   },
                   whippy_custom_object_record_id: "9384c91d-8d7a-43ee-8836-6b212f2650ac"
                 }
               } =
                 WhippyClient.update_custom_object_record("api_key", "123", "456", %{})
      end
    end
  end

  describe "send_message/4" do
    test "Send message through API" do
      with_mock HTTPoison,
        request: fn _method, url, _body, _header, _opts ->
          assert url =~ "v1/messaging/sms"
        end do
        WhippyClient.send_message("api_key", "123", "456", %{})
      end
    end
  end
end
