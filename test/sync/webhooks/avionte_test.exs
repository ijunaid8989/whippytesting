defmodule Sync.Webhooks.AvionteTest do
  use Sync.DataCase, async: false

  import ExUnit.CaptureLog
  import Mock
  import Sync.Factory
  import Sync.Fixtures.AvionteClient

  alias Sync.Contacts.Contact
  alias Sync.Integrations
  alias Sync.Repo
  alias Sync.Webhooks.Avionte
  alias Sync.Workers.Whippy

  describe "process_event/1" do
    test "logs an error when an integration record does not exist for the external organization" do
      event = talent_created_webhook_event_fixture()

      assert capture_log(fn -> Avionte.process_event(event) end) =~ "Integration not found for event: #{inspect(event)}"
    end
  end

  describe "process_event/2 for talent_created events" do
    setup [:with_integration]

    test "does not process the event if the talent already exists in Sync as a contact", %{integration: integration} do
      event = talent_created_webhook_event_fixture()
      insert(:contact, external_contact_id: "662", integration_id: integration.id)

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_talents_fixture(limit: 1) end},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => "123"}}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = Repo.all(Sync.Contacts.Contact)

        assert_not_called(HTTPoison.post(:_, :_, :_, :_))
        assert_not_called(Sync.Clients.Whippy.Contacts.create_contact(:_, :_))
      end
    end

    test "makes a request to fetch a Talent and syncs it to Whippy when the contact does not exist in Sync", %{
      integration: integration
    } do
      event = talent_created_webhook_event_fixture()

      _mapped_branch =
        insert(:channel,
          integration: integration,
          external_channel_id: "25208",
          whippy_channel_id: "42"
        )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_talents_fixture(limit: 1) end},
        {Whippy.Writer, [], [send_contacts_to_whippy: fn :avionte, _integration, [_contact] -> {:ok, %{}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = contacts = Repo.all(Sync.Contacts.Contact)
        assert Enum.all?(contacts, fn contact -> contact.whippy_channel_id == "42" end)
        assert_called(Whippy.Writer.send_contacts_to_whippy(:_, :_, :_))
      end
    end

    test "converts the Talent to CustomObjectRecord when the custom data sync is enabled", %{integration: integration} do
      event = talent_created_webhook_event_fixture()
      {:ok, _integration} = Integrations.update_integration(integration, %{settings: %{"sync_custom_data" => true}})

      insert(:custom_object,
        integration: integration,
        external_entity_type: "talent",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_talents_fixture(limit: 1) end},
        {Whippy.Writer, [],
         [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> {:ok, %{}} end]},
        {Whippy.Writer, [],
         [
           send_contacts_to_whippy: fn :avionte, _integration, [contact] ->
             contact
             |> Contact.whippy_update_changeset(%{
               whippy_contact_id: "1234",
               whippy_organization_id: "12345",
               whippy_contact: %{}
             })
             |> Repo.update()

             :ok
           end
         ]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))
        assert [%Contact{}] = Repo.all(Contact)

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   whippy_associated_resource_id: "1234",
                   whippy_associated_resource_type: "contact",
                   external_custom_object_record_id: "662"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end
  end

  describe "process_event/2 for talent_merged events" do
    setup [:with_integration]

    test "syncs the good talent, when the bad talent does not exist" do
      event = talent_merged_webhook_event_fixture()

      with_mocks([
        {HTTPoison, [],
         post: fn _url, body, _header, _opts ->
           assert ["662"] == Jason.decode!(body)
           list_talents_fixture(limit: 1)
         end},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => "123"}}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = Repo.all(Sync.Contacts.Contact)
        assert_called(HTTPoison.post(:_, :_, :_, :_))
        assert_called(Sync.Clients.Whippy.Contacts.create_contact(:_, :_))
      end
    end

    test "overwrites the bad talent with the good talent's data, when the bad talent exists only in the sync app", %{
      integration: integration
    } do
      event = talent_merged_webhook_event_fixture()
      good_talent_id = "662"
      bad_talent_id = "942"
      insert(:contact, integration: integration, external_contact_id: bad_talent_id, integration_id: integration.id)

      with_mocks([
        {HTTPoison, [],
         post: fn _url, body, _header, _opts ->
           assert [good_talent_id] == Jason.decode!(body)
           list_talents_fixture(limit: 1)
         end},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => "123"}}} end]}
      ]) do
        Avionte.process_event(event)
        assert [%Sync.Contacts.Contact{external_contact_id: ^good_talent_id}] = Repo.all(Sync.Contacts.Contact)
        assert_called(HTTPoison.post(:_, :_, :_, :_))
        assert_called(Sync.Clients.Whippy.Contacts.create_contact(:_, :_))
      end
    end

    test "overwrites the bad talent with the good talent's data, when the bad talent exists in both sync and whippy apps",
         %{integration: integration} do
      event = talent_merged_webhook_event_fixture()
      good_talent_id = "662"
      bad_talent_id = "942"

      _bad_talent =
        insert(:contact,
          integration: integration,
          whippy_contact_id: "1234",
          external_contact_id: bad_talent_id,
          integration_id: integration.id
        )

      _activity =
        insert(:activity,
          whippy_contact_id: "1234",
          external_contact_id: bad_talent_id,
          integration: integration,
          external_activity_id: "1234"
        )

      with_mocks([
        {HTTPoison, [],
         post: fn _url, _body, _header, _opts -> list_talents_fixture(limit: 1, ids: [good_talent_id]) end},
        {Sync.Clients.Whippy.Contacts, [],
         [update_contact: fn _integration, _id, _body -> {:ok, %{"data" => %{"id" => "1234"}}} end]}
      ]) do
        Avionte.process_event(event)
        assert [%Sync.Contacts.Contact{external_contact_id: ^good_talent_id}] = Repo.all(Sync.Contacts.Contact)
        assert [%Sync.Activities.Activity{external_contact_id: ^good_talent_id}] = Repo.all(Sync.Activities.Activity)
      end
    end

    test "converts the good talent to CustomObjectRecord when the custom data sync is enabled", %{
      integration: integration
    } do
      event = talent_merged_webhook_event_fixture()
      {:ok, _integration} = Integrations.update_integration(integration, %{settings: %{"sync_custom_data" => true}})

      insert(:custom_object,
        integration: integration,
        external_entity_type: "talent",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      _bad_talent =
        insert(:contact,
          integration: integration,
          whippy_contact_id: "1234",
          external_contact_id: "942",
          integration_id: integration.id
        )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_talents_fixture(limit: 1) end},
        {Whippy.Writer, [], [update_whippy_contact: fn _integration, _contact, _payload, _id -> {:ok, %{}} end]},
        {Whippy.Writer, [],
         [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> {:ok, %{}} end]}
      ]) do
        Avionte.process_event(event)
        assert [%Sync.Contacts.Contact{}] = Repo.all(Sync.Contacts.Contact)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))
      end
    end
  end

  describe "process_event/2 for contact_created events" do
    setup [:with_integration]

    test "does not process the event if the contact already exists in Sync as a contact", %{integration: integration} do
      event = contact_created_webhook_event_fixture()
      insert(:contact, external_contact_id: "contact-86635", integration_id: integration.id)

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_contact_fixture() end},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => "123"}}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = Repo.all(Sync.Contacts.Contact)

        assert_not_called(HTTPoison.post(:_, :_, :_, :_))
        assert_not_called(Sync.Clients.Whippy.Contacts.create_contact(:_, :_))
      end
    end

    test "makes a request to fetch a Contact and syncs it to Whippy when the contact does not exist in Sync", %{
      integration: integration
    } do
      event = contact_created_webhook_event_fixture()

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_contact_fixture() end},
        {Whippy.Writer, [], [send_contacts_to_whippy: fn :avionte, _integration, [_contact] -> {:ok, %{}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = contacts = Repo.all(Sync.Contacts.Contact)
        assert Enum.all?(contacts, fn contact -> contact.external_contact_id == "contact-86635" end)
        assert_called(Whippy.Writer.send_contacts_to_whippy(:_, :_, :_))
      end
    end

    test "converts the Contact to CustomObjectRecord when the custom data sync is enabled", %{integration: integration} do
      event = contact_created_webhook_event_fixture()

      {:ok, _integration} =
        Integrations.update_integration(integration, %{
          settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}
        })

      insert(:custom_object,
        integration: integration,
        external_entity_type: "avionte_contact",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_contact_fixture() end},
        {Whippy.Writer, [],
         [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> {:ok, %{}} end]},
        {Whippy.Writer, [],
         [
           send_contacts_to_whippy: fn :avionte, _integration, [contact] ->
             contact
             |> Contact.whippy_update_changeset(%{
               whippy_contact_id: "1234",
               whippy_organization_id: "12345",
               whippy_contact: %{}
             })
             |> Repo.update()

             :ok
           end
         ]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))
        assert [%Contact{}] = Repo.all(Contact)

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   whippy_associated_resource_id: "1234",
                   whippy_associated_resource_type: "contact",
                   external_custom_object_record_id: "contact-86635"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end
  end

  describe "process_event/2 for contact_updated events" do
    setup [:with_integration]

    test "updates the contact in Sync when the contact is updated in Avionte", %{integration: integration} do
      event = contact_updated_webhook_event_fixture()

      insert(:contact,
        external_contact_id: "contact-86635",
        integration_id: integration.id,
        external_organization_id: "6",
        whippy_organization_id: "e276e333-f240-4cea-bb7b-831ed0ce264a",
        whippy_contact_id: "123"
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_contact_fixture() end},
        {Sync.Clients.Whippy.Contacts, [],
         [create_contact: fn _integration, _contact -> {:ok, %{"data" => %{"id" => "123"}}} end]}
      ]) do
        assert Avionte.process_event(event) == :ok
        assert [%Sync.Contacts.Contact{}] = Repo.all(Sync.Contacts.Contact)

        assert_called(HTTPoison.post(:_, :_, :_, :_))
        assert_called(Sync.Clients.Whippy.Contacts.create_contact(:_, :_))
      end
    end
  end

  describe "process_event/2 for placement_created events" do
    setup [:with_integration]

    test "converts the placement to CustomObjectRecord when the custom data sync is enabled", %{integration: integration} do
      event = placement_created_webhook_event_fixture()

      {:ok, _integration} =
        Integrations.update_integration(integration, %{
          settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}
        })

      insert(:custom_object,
        integration: integration,
        external_entity_type: "placements",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_placements_fixture() end},
        {Whippy.Writer, [], [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> :ok end]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   external_custom_object_record_id: "96993923"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end

    test "converts the placement updated to CustomObjectRecord when the custom data sync is enabled", %{
      integration: integration
    } do
      event = placement_updated_webhook_event_fixture()

      {:ok, _integration} =
        Integrations.update_integration(integration, %{
          settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}
        })

      insert(:custom_object,
        integration: integration,
        external_entity_type: "placements",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_placements_fixture() end},
        {Whippy.Writer, [], [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> :ok end]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   external_custom_object_record_id: "96993923"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end
  end

  describe "process_event/2 for company_updated events" do
    setup [:with_integration]

    test "converts the company to CustomObjectRecord when the custom data sync is enabled", %{integration: integration} do
      event = company_updated_webhook_event_fixture()

      {:ok, _integration} =
        Integrations.update_integration(integration, %{
          settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}
        })

      insert(:custom_object,
        integration: integration,
        external_entity_type: "companies",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_companies_fixture() end},
        {Whippy.Writer, [], [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> :ok end]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   external_custom_object_record_id: "10848976"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end
  end

  describe "process_event/2 for job_updated events" do
    setup [:with_integration]

    test "converts the job to CustomObjectRecord when the custom data sync is enabled", %{integration: integration} do
      event = job_updated_webhook_event_fixture()

      {:ok, _integration} =
        Integrations.update_integration(integration, %{
          settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}
        })

      insert(:custom_object,
        integration: integration,
        external_entity_type: "jobs",
        whippy_custom_object_id: "1",
        whippy_organization_id: integration.whippy_organization_id
      )

      with_mocks([
        {HTTPoison, [], post: fn _url, _header, _body, _opts -> list_jobs_fixture() end},
        {Whippy.Writer, [], [send_custom_object_records_to_whippy: fn _integration, _custom_object_records -> :ok end]}
      ]) do
        Avionte.process_event(event)
        assert_called(Whippy.Writer.send_custom_object_records_to_whippy(:_, :_))

        assert [
                 %Sync.Contacts.CustomObjectRecord{
                   external_custom_object_record_id: "38870859"
                 }
               ] = Repo.all(Sync.Contacts.CustomObjectRecord)
      end
    end
  end

  defp with_integration(_context) do
    integration =
      insert(:integration,
        client: :avionte,
        external_organization_id: "6",
        integration: "avionte",
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
          "fallback_external_user_id" => 1245
        }
      )

    {:ok, integration: integration}
  end
end
