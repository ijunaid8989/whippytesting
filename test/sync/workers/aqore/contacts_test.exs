defmodule Sync.Workers.Aqore.ContactsTest do
  use Sync.DataCase, async: false
  use Oban.Testing, repo: Sync.Repo

  import Mock
  import Sync.Factory

  alias Sync.Contacts.Contact
  alias Sync.Repo
  alias Sync.Workers.Aqore.Contacts

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

  describe "Full sync process/1" do
    test "pulls contacts from Aqore and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], http_poison_mocks()) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Contacts, %{
                   "type" => "pull_contacts_from_aqore",
                   "integration_id" => integration.id
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" &&
                   contact.phone == "+12182349095" &&
                   contact.email == "hhh@h.com"
               end)
      end
    end
  end

  describe "Daily sync process/1" do
    test "pulls contacts from Aqore and saves them as contacts", %{integration: integration} do
      with_mock(HTTPoison, [], http_poison_mocks(:contacts)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Contacts, %{
                   "type" => "daily_pull_contacts_from_aqore",
                   "integration_id" => integration.id,
                   "sync_date" => "2025-01-01"
                 })

        assert [%Contact{} | _] = contacts = Repo.all(Contact)

        assert Enum.all?(contacts, fn contact ->
                 contact.external_organization_id == "test_external_organization_id" &&
                   contact.phone == "+12182349095"
               end)
      end
    end

    test "pulls contacts from Aqore second time in daily sync when the response is an 15mins interval message", %{
      integration: integration
    } do
      with_mock(HTTPoison, [], httpoison_mock(:aqore_pull_error)) do
        assert [] == Repo.all(Contact)

        assert :ok ==
                 perform_job(Contacts, %{
                   "type" => "daily_pull_contacts_from_aqore",
                   "integration_id" => integration.id,
                   "sync_date" => "2025-01-01"
                 })
      end
    end
  end

  defp http_poison_mocks do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.list_contact_fixture()
      end
    ]
  end

  defp http_poison_mocks(:contacts) do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.list_contacts_fixture()
      end
    ]
  end

  defp httpoison_mock(:aqore_pull_error) do
    [
      post: fn _url, _body, _headers ->
        Sync.Fixtures.AqoreClient.token_fixture()
      end,
      post: fn _url, _headers, _opts, _ ->
        Sync.Fixtures.AqoreClient.message_error_fixture()
      end
    ]
  end
end
