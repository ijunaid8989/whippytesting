defmodule Sync.Workers.Avionte.TalentsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory

  alias Sync.Clients.Avionte
  alias Sync.Clients.Whippy
  alias Sync.Contacts.Contact
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Avionte.Talents

  setup do
    integration =
      insert(:integration,
        integration: "avionte",
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

    integration_with_branches =
      insert(:integration,
        integration: "avionte",
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
        },
        settings: %{
          "branches_mapping" => [
            %{
              "office_name" => "test_office_name",
              "branch_id" => "test_branch_id",
              "organization_id" => "test_whippy_organization_id",
              "fallback_external_user_id" => "12245",
              "should_sync_to_avionte" => false,
              "whippy_api_key" => "ca5d254d-d2d5-4d7f-80fd-f745bbf17c3f"
            }
          ]
        }
      )

    # The tests of talents assume the users have already been synced
    insert(:user, integration: integration, external_user_id: "12245", whippy_user_id: "1")
    insert(:user, integration: integration_with_branches, external_user_id: "12246", whippy_user_id: "2")
    %{integration: integration, integration_with_branches: integration_with_branches}
  end

  describe "process/1" do
    test "pulls talents from Avionte and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:avionte_list, :success)) do
        assert [] == Repo.all(Contact)

        _mapped_branch =
          insert(:channel,
            integration: integration,
            external_channel_id: "25208",
            whippy_channel_id: "42"
          )

        assert :ok == perform_job(Talents, %{"type" => "pull_talents_from_avionte", "integration_id" => integration.id})

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.external_organization_id == "test_external_organization_id" end)
      end
    end

    test "pull talent from Avionte and saves them as contact", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_channel_id)) do
        assert [] == Repo.all(Contact)

        _mapped_branch =
          insert(:channel,
            integration: integration,
            external_channel_id: "25208",
            whippy_channel_id: "42"
          )

        assert :ok == perform_job(Talents, %{"type" => "pull_talents_from_avionte", "integration_id" => integration.id})

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.external_organization_id == "test_external_organization_id" end)
        assert Enum.all?(contacts, fn contact -> contact.whippy_channel_id == "42" end)
      end
    end

    test "pulls talents from Avionte and saves them as contacts with external_contact_hash and sync_to_whippy", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:avionte_list, :success)) do
        insert(:contact,
          integration: integration,
          external_organization_id: "test_external_organization_id",
          whippy_organization_id: "test_whippy_organization_id",
          whippy_contact_id: "test_whippy_contact_id",
          whippy_contact: %Whippy.Model.Contact{
            id: "test_whippy_contact_id",
            name: nil,
            email: "some@email.com",
            phone: "+1234567890"
          }
        )

        assert :ok == perform_job(Talents, %{"type" => "pull_talents_from_avionte", "integration_id" => integration.id})

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.external_organization_id == "test_external_organization_id" end)
        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == true end)
      end
    end

    test "pulls talents from Avionte and skips a batch of Talent IDs after retry attempts are exhausted", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:avionte_list, :failure)) do
        assert [] == Repo.all(Contact)

        captured_log =
          capture_log(fn ->
            assert :ok ==
                     perform_job(Talents, %{"type" => "pull_talents_from_avionte", "integration_id" => integration.id})
          end)

        assert captured_log =~ "Received 500 response from get http://test.com"
        assert captured_log =~ "Skipping batch of talents:"
      end
    end

    test "pulls talents from Avionte and skips archived talents", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:avionte_list, :success)) do
        assert [] == Repo.all(Contact)

        assert :ok == perform_job(Talents, %{"type" => "pull_talents_from_avionte", "integration_id" => integration.id})

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.external_organization_id == "test_external_organization_id" end)
        assert Enum.all?(contacts, fn contact -> contact.external_contact["isArchived"] == false end)
      end
    end

    test "pulls contacts from Whippy and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_list)) do
        assert [] == Repo.all(Contact)

        assert :ok == perform_job(Talents, %{"type" => "pull_contacts_from_whippy", "integration_id" => integration.id})

        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.whippy_organization_id == "test_whippy_organization_id" end)
      end
    end

    test "pushes Whippy contacts into Avionte", %{integration: integration} do
      with_mock(HTTPoison, [],
        post: fn _url, params, _headers, _opts ->
          expected_params = %{
            "origin" => "whippy",
            "representativeUser" => "12245",
            "mobilePhone" => "+1234567890",
            "firstName" => "+1234567890",
            "lastName" => "unknown",
            "emailAddress" => "some@email.com"
          }

          assert Jason.decode!(params) == expected_params
          Fixtures.AvionteClient.create_talent_fixture()
        end,
        request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_conversations_fixture() end
      ) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: nil,
              email: "some@email.com",
              phone: "+1234567890"
            }
          )

        assert :ok == perform_job(Talents, %{"type" => "push_contacts_to_avionte", "integration_id" => integration.id})

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: "2911805"} | _] =
                 Repo.all(Contact)
      end
    end

    test "do not push Whippy contacts into Avionte if email is not present", %{integration: integration} do
      with_mock(HTTPoison, [],
        post: fn _url, params, _headers, _opts ->
          expected_params = %{
            "origin" => "whippy",
            "representativeUser" => "12245",
            "mobilePhone" => "+1234567890",
            "firstName" => "John",
            "lastName" => "unknown",
            "emailAddress" => nil
          }

          assert Jason.decode!(params) == expected_params
          Fixtures.AvionteClient.create_talent_fixture()
        end,
        request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_conversations_fixture() end
      ) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "John",
              email: nil,
              phone: "+1234567890"
            }
          )

        assert :ok == perform_job(Talents, %{"type" => "push_contacts_to_avionte", "integration_id" => integration.id})

        assert [%Contact{whippy_contact_id: "test_whippy_contact_id", external_contact_id: nil} | _] =
                 Repo.all(Contact)
      end
    end

    test "pushes Avionte talents into Whippy", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "address" => %{
              "address_line_one" => "123 Main St",
              "address_line_two" => nil,
              "city" => "Anytown",
              "country" => nil,
              "post_code" => "12345",
              "state" => "NY"
            },
            "birth_date" => %{"day" => 1, "month" => 1, "year" => 1981},
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "integration_id" => integration.id
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _avionte_talent =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            address: %{
              street1: "123 Main St",
              street2: nil,
              city: "Anytown",
              state_Province: "NY",
              postalCode: "12345",
              country: nil
            },
            email: nil,
            external_contact: %Avionte.Model.Talent{
              id: "2911805",
              mobilePhone: "+1234567890",
              firstName: "John",
              lastName: "Doe",
              emailAddress: nil,
              birthday: NaiveDateTime.new!(1981, 1, 1, 0, 0, 0),
              addresses: [
                %Avionte.Model.Address{
                  street1: "123 Main St",
                  city: "Anytown",
                  state_Province: "NY",
                  postalCode: "12345"
                }
              ]
            }
          )

        assert :ok == perform_job(Talents, %{"type" => "push_talents_to_whippy", "integration_id" => integration.id})
      end
    end

    test "pushes Avionte talents into Whippy and set should_sync_to_whippy to false", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "address" => %{
              "address_line_one" => "123 Main St",
              "address_line_two" => nil,
              "city" => "Anytown",
              "country" => nil,
              "post_code" => "12345",
              "state" => "NY"
            },
            "birth_date" => %{"day" => 1, "month" => 1, "year" => 1981},
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "integration_id" => integration.id
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        _avionte_talent =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            should_sync_to_whippy: true,
            address: %{
              street1: "123 Main St",
              street2: nil,
              city: "Anytown",
              state_Province: "NY",
              postalCode: "12345",
              country: nil
            },
            email: nil,
            external_contact: %Avionte.Model.Talent{
              id: "2911805",
              mobilePhone: "+1234567890",
              firstName: "John",
              lastName: "Doe",
              emailAddress: nil,
              birthday: NaiveDateTime.new!(1981, 1, 1, 0, 0, 0),
              addresses: [
                %Avionte.Model.Address{
                  street1: "123 Main St",
                  city: "Anytown",
                  state_Province: "NY",
                  postalCode: "12345"
                }
              ]
            }
          )

        assert :ok == perform_job(Talents, %{"type" => "push_talents_to_whippy", "integration_id" => integration.id})
        assert [%Contact{} | _] = contacts = Repo.all(Contact)
        assert Enum.all?(contacts, fn contact -> contact.should_sync_to_whippy == false end)
      end
    end

    test "pushes Avionte talents into Whippy and set should_sync_to_whippy to false for branched integration", %{
      integration_with_branches: integration_with_branches
    } do
      with_mock(HTTPoison, [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
            "address" => %{
              "address_line_one" => "123 Main St",
              "address_line_two" => nil,
              "city" => "Anytown",
              "country" => nil,
              "post_code" => "12345",
              "state" => "NY"
            },
            "birth_date" => %{"day" => 1, "month" => 1, "year" => 1981},
            "email" => nil,
            "external_id" => "2911805",
            "name" => "John Doe",
            "phone" => "+1234567890",
            "integration_id" => integration_with_branches.id
          }

          assert Jason.decode!(body) == expected_body
          Fixtures.WhippyClient.create_contact_fixture()
        end
      ) do
        avionte_talent_1 =
          insert(:contact,
            integration: integration_with_branches,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            should_sync_to_whippy: true,
            address: %{
              street1: "123 Main St",
              street2: nil,
              city: "Anytown",
              state_Province: "NY",
              postalCode: "12345",
              country: nil
            },
            email: nil,
            external_contact: %Avionte.Model.Talent{
              officeName: "test_office_name",
              id: "2911805",
              mobilePhone: "+1234567890",
              firstName: "John",
              lastName: "Doe",
              emailAddress: nil,
              birthday: NaiveDateTime.new!(1981, 1, 1, 0, 0, 0),
              addresses: [
                %Avionte.Model.Address{
                  street1: "123 Main St",
                  city: "Anytown",
                  state_Province: "NY",
                  postalCode: "12345"
                }
              ]
            }
          )

        avionte_talent_2 =
          insert(:contact,
            integration: integration_with_branches,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911806",
            name: "John Doe 2",
            phone: "+1234567891",
            should_sync_to_whippy: true,
            address: %{
              street1: "123 Main St",
              street2: nil,
              city: "Anytown",
              state_Province: "NY",
              postalCode: "12345",
              country: nil
            },
            email: nil,
            external_contact: %Avionte.Model.Talent{
              officeName: "test_office_name_2",
              id: "2911806",
              mobilePhone: "+1234567891",
              firstName: "John",
              lastName: "Doe 2",
              emailAddress: nil,
              birthday: NaiveDateTime.new!(1981, 1, 1, 0, 0, 0),
              addresses: [
                %Avionte.Model.Address{
                  street1: "123 Main St",
                  city: "Anytown",
                  state_Province: "NY",
                  postalCode: "12345"
                }
              ]
            }
          )

        assert :ok ==
                 perform_job(Talents, %{
                   "type" => "push_talents_to_whippy",
                   "integration_id" => integration_with_branches.id
                 })

        assert Repo.reload(avionte_talent_1).should_sync_to_whippy == false
        assert Repo.reload(avionte_talent_2).should_sync_to_whippy == true
      end
    end
  end

  defp httpoison_mock(:avionte_list, type) do
    list_talents_fixture =
      case type do
        :success ->
          Fixtures.AvionteClient.list_talents_fixture()

        :failure ->
          {:ok,
           %HTTPoison.Response{
             status_code: 500,
             body: "Internal Server Error",
             request: %HTTPoison.Request{url: "http://test.com"}
           }}
      end

    [
      post: fn _url, _params, _headers, _opts -> list_talents_fixture end,
      get: fn _url, _headers, _opts -> Fixtures.AvionteClient.list_talent_ids_fixture() end
    ]
  end

  defp httpoison_mock(:whippy_list) do
    [
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_contacts_fixture() end
    ]
  end

  defp httpoison_mock(:whippy_channel_id) do
    [
      post: fn _url, _params, _headers, _opts -> Fixtures.AvionteClient.list_talents_channel_id_fixture() end,
      get: fn _url, _headers, _opts -> Fixtures.AvionteClient.list_talent_ids_fixture() end
    ]
  end
end
