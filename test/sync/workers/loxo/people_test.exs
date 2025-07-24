defmodule Sync.Workers.Loxo.PeopleTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Clients.Loxo
  alias Sync.Clients.Whippy
  alias Sync.Contacts.Contact
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Loxo.People

  setup do
    integration =
      insert(:integration,
        integration: "loxo",
        whippy_organization_id: "test_whippy_organization_id",
        external_organization_id: "test_external_organization_id",
        authentication: %{
          "external_api_key" => "test_loxo_api_key",
          "whippy_api_key" => "test_whippy_api_key",
          "agency_slug" => "test_agency_slug"
        }
      )

    # The tests of people assume the users have already been synced
    insert(:user, integration: integration, external_user_id: "12245", whippy_user_id: "1")

    %{integration: integration}
  end

  describe "process/1" do
    test "pulls people from Loxo and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:loxo_list, :success)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(People, %{
                   "type" => "pull_people_from_loxo",
                   "integration_id" => integration.id
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

        assert :ok ==
                 perform_job(People, %{
                   "type" => "pull_contacts_from_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.whippy_organization_id == "test_whippy_organization_id"
               end)
      end
    end

    test "pushes Whippy contacts into Loxo", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:loxo_push)) do
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
            },
            external_contact_id: "166640410"
          )

        assert :ok ==
                 perform_job(People, %{
                   "type" => "push_contacts_to_loxo",
                   "integration_id" => integration.id
                 })

        assert [
                 %Contact{
                   whippy_contact_id: "test_whippy_contact_id",
                   external_contact_id: "166640410"
                 }
                 | _
               ] = Repo.all(Contact)
      end
    end

    test "pushes Loxo people into Whippy", %{integration: integration} do
      with_mock(HTTPoison, [],
        request: fn :post, _url, body, _header, _opts ->
          expected_body = %{
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
        _loxo_person =
          insert(:contact,
            integration: integration,
            external_organization_id: "test_external_organization_id",
            whippy_organization_id: nil,
            external_contact_id: "2911805",
            name: "John Doe",
            phone: "+1234567890",
            email: nil,
            external_contact: %Loxo.Model.Person{
              id: "2911805",
              name: "John Doe",
              phones: [
                %{
                  value: "+1234567890",
                  id: 134_888_257,
                  phone_type_id: 144_403
                }
              ],
              emails: []
            }
          )

        assert :ok ==
                 perform_job(People, %{
                   "type" => "push_people_to_whippy",
                   "integration_id" => integration.id
                 })
      end
    end
  end

  defp httpoison_mock(:loxo_list, type) do
    list_people_fixture =
      case type do
        :success ->
          Fixtures.LoxoClient.list_people_fixture()

        :failure ->
          {:ok,
           %HTTPoison.Response{
             status_code: 500,
             body: "Internal Server Error",
             request: %HTTPoison.Request{url: "http://test.com"}
           }}
      end

    [
      post: fn _url, _params, _headers, _opts -> list_people_fixture end,
      get: fn _url, _headers -> Fixtures.LoxoClient.list_people_fixture() end
    ]
  end

  defp httpoison_mock(:loxo_push) do
    [
      post: fn _url, _params, _headers, _opts -> Fixtures.LoxoClient.create_person_fixture() end,
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_conversations_fixture() end
    ]
  end

  defp httpoison_mock(:whippy_list) do
    [
      request: fn :get, _url, _body, _header, _opts -> Fixtures.WhippyClient.list_contacts_fixture() end
    ]
  end
end
