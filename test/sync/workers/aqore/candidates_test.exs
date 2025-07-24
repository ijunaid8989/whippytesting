defmodule Sync.Workers.Aqore.CandidatesTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Clients.Whippy
  alias Sync.Contacts.Contact
  alias Sync.Fixtures
  alias Sync.Repo
  alias Sync.Workers.Aqore.Candidates

  setup do
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
          "access_token" =>
            "eyJhbGciOiJSUzI1NiIsImtpZCI6IjY1MTdDM0VBNTYwRDJBOEI5QjkzQ0QzOEU2QjhDNEQwRTYzNkY5QTlSUzI1NiIsInR5cCI6ImF0K2p3dCIsIng1dCI6IlpSZkQ2bFlOS291Yms4MDQ1cmpFME9ZMi1hayJ9.eyJuYmYiOjE3MzQ3MTg2MTAsImV4cCI6MTczNDcyNTgxMCwiaXNzIjoiaHR0cHM6Ly96ZW5vcGxlaHViYXBpLnplbm9wbGUuY29tIiwiY2xpZW50X2lkIjoiV25QU2pvdGFrVUtFbjM4T1ZMQzVvTHFFY2tyZlBvZkgyYkpEVThvNXZBZz0iLCJjbGllbnRfZ3JhbnRUeXBlIjoiY2xpZW50X2NyZWRlbnRpYWxzIiwiY2xpZW50X3BlcnNvbklkIjoiMiIsImNsaWVudF9jbGllbnROYW1lIjoiVGhpcmRQYXJ0eSIsImNsaWVudF9yZXF1ZXN0TGltaXQiOiIyMDAiLCJjbGllbnRfcGVybWlzc2lvbiI6ImNvbW1vbi9kYXRhIiwianRpIjoiQUQ5QTcxNjMzQzA1RDVGN0EzREFDQzUxRkFDRDkzMzYiLCJpYXQiOjE3MzQ3MTg2MTAsInNjb3BlIjpbInplbm9wbGVBcGkiXX0.VCtNPnL2Dj4Unubsiuup03ptag42cFjUGv_Vj6wiMWHOMy6oLwTkJEAHes-A5mpEBKbFO_JV0VoJKH0VLXN9BmlWLEFgFLl1DzsDhTEzbuCyN_iyW75N1UGTOgH1xm-wtDF3_XKjk9fXobEj-Obf8otNgaRRh3KrHevudNlw3XCn2ydhXe1KDMuvFKs7hPG8YMIDo6gwNSQNLPRo_FQ7o7tuYQdv2pB7fCYiK4t49z4fMS3uaKd0VqAYK6tXtfa2Kuuhf23eGOPo_wzhsUkIEUFkXxndfOS0I0GAXDz_Ix25KY1SWgjqJKeK_gPuvVTsRdUTvwbTK0laYG5TyRMVeA",
          "requests_made" => 0,
          "base_api_url" => "https://www.google.com"
        },
        settings: %{
          office_id: 100_234,
          office_name: "Chicago"
        }
      )

    %{integration: integration}
  end

  describe "daily process/1" do
    # integrations/sync/test/sync/workers/aqore/candidates_test.exs
    test "pulls candidates from Aqore and saves them as contacts in full sync", %{integration: integration} do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "pull_candidates_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.phone == "+923008637777" and
                   contact.email == "hhh@h.com"
               end)
      end
    end

    test "pulls candidates from Aqore and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "daily_pull_candidates_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.phone == "+923008637777" and
                   contact.email == "hhh@h.com"
               end)
      end
    end

    test "pulls candidates from Aqore and update the contact details which is already present in sync db", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        insert(:contact,
          integration: integration,
          external_organization_id: nil,
          whippy_organization_id: "test_whippy_organization_id",
          whippy_contact_id: "test_whippy_contact_id",
          phone: "+923008637777",
          name: nil,
          whippy_contact: %Whippy.Model.Contact{
            id: "test_whippy_contact_id",
            phone: "+1923008637777"
          }
        )

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "daily_pull_candidates_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.email == "hhh@h.com"
               end)
      end
    end

    test "pulls candidates from Aqore and saves them as contacts only the contacts which doesn't have zzz in lastname", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], http_poison_mocks(:aqore_pull)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "daily_pull_candidates_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.email == "hhh@h.com"
               end)
      end
    end

    test "lookup candidates from Aqore and update the contact details which is already present in sync db", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        insert(:contact,
          integration: integration,
          external_organization_id: nil,
          whippy_organization_id: "test_whippy_organization_id",
          whippy_contact_id: "test_whippy_contact_id",
          phone: "+923008637777",
          name: nil,
          whippy_contact: %Whippy.Model.Contact{
            id: "test_whippy_contact_id",
            phone: "+1923008637777"
          }
        )

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "lookup_candidates_in_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.name == "Paul Clements" and
                   contact.email == "hhh@h.com"
               end)
      end
    end

    test "push candidates to Aqore", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:aqore_push)) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: "Paul Clements",
            email: "paul@gmail.com",
            phone: "+923008637777",
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Paul Clements",
              phone: "+923008637777",
              email: "paul@gmail.com"
            }
          )

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "push_contacts_to_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.phone == "+923008637777" and
                   contact.external_contact["external_contact_id"] == "1"
               end)
      end
    end

    test "push candidates to Aqore when email is nil", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:aqore_push)) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: "Paul Clements",
            phone: "+923008637777",
            email: nil,
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: "Paul Clements",
              phone: "+923008637777"
            }
          )

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "push_contacts_to_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.phone == "+923008637777" and
                   contact.external_contact["external_contact_id"] == "1"
               end)
      end
    end

    test "push candidates to Aqore when name is nil", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:aqore_push)) do
        _whippy_contact =
          insert(:contact,
            integration: integration,
            external_organization_id: nil,
            whippy_organization_id: "test_whippy_organization_id",
            whippy_contact_id: "test_whippy_contact_id",
            name: nil,
            phone: "+923008637777",
            email: nil,
            whippy_contact: %Whippy.Model.Contact{
              id: "test_whippy_contact_id",
              name: nil,
              phone: "+923008637777"
            }
          )

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "push_contacts_to_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" and
                   contact.phone == "+923008637777" and
                   contact.external_contact["external_contact_id"] == "1"
               end)
      end
    end

    test "pulls contacts from Whippy and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], httpoison_mock(:whippy_list)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "pull_contacts_from_whippy",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.whippy_organization_id == "test_whippy_organization_id"
               end)
      end
    end

    test "pulls candidates from Aqore second time in daily sync when the response is an 15mins interval message", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:aqore_pull_error)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Candidates, %{
                   "type" => "daily_pull_candidates_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [] == Repo.all(Contact)
      end
    end
  end

  defp http_poison_mocks do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.list_candidates_fixture()
      end
    ]
  end

  defp http_poison_mocks(:aqore_pull) do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.list_candidates_with_zzz_as_lastname_fixture()
      end
    ]
  end

  defp httpoison_mock(:aqore_push) do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _params, _headers, _opts ->
        Fixtures.AqoreClient.new_candidates_fixture()
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

  defp httpoison_mock(:aqore_pull_error) do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Fixtures.AqoreClient.message_error_fixture()
      end
    ]
  end
end
