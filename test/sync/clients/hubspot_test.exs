defmodule Sync.Clients.HubspotTest do
  use ExUnit.Case, async: true

  import Sync.Fixtures.HubspotClient

  alias Sync.Clients.Hubspot

  describe "pull_contacts/2" do
    test "Without cursor" do
      {:ok, contacts} =
        Hubspot.pull_contacts(fn _, path, _, _ ->
          case path do
            "/crm/v4/objects/contacts?archived=false&limit=100&properties=phone%2Cemail%2Cfirstname%2Clastname" ->
              pull_contacts()

            "/crm/v4/associations/contacts/companies/batch/read" ->
              %{"results" => []}
          end
        end)

      assert length(contacts) > 0
    end

    test "With cursor" do
      {:ok, _, cursor} =
        Hubspot.pull_contacts(
          fn _, path, _, _ ->
            case path do
              "/crm/v4/objects/contacts?after=26256445664&archived=false&limit=100&properties=phone%2Cemail%2Cfirstname%2Clastname" ->
                pull_contacts_paginated()

              "/crm/v4/associations/contacts/companies/batch/read" ->
                %{"results" => []}
            end
          end,
          "26256445664"
        )

      assert byte_size(cursor) > 0
    end
  end

  describe "push_contacts/2" do
    test "Make sure hubspot returns same number of contacts" do
      whippy_contacts = get_whippy_contacts()

      contacts =
        Hubspot.push_contacts(
          fn method, path, _, _ ->
            assert method == :post
            assert path == "/crm/v4/objects/contacts/batch/create"

            push_contacts()
          end,
          whippy_contacts
        )

      assert length(contacts) == length(whippy_contacts)
    end
  end

  describe "push_activities/2" do
    test "Make sure only communication api was called" do
      Hubspot.push_activities(
        fn _, path, _, _ ->
          assert path == "/crm/v3/objects/communications/batch/create"
        end,
        get_sms_activities()
      )
    end

    test "Make sure only communication api was not called" do
      Hubspot.push_activities(
        fn _, path, _, _ ->
          assert path != "/crm/v3/objects/communications/batch/create"
        end,
        get_not_sms_activities()
      )
    end
  end

  describe "search_contacts_by_id/2" do
    test "Search contacts by ids" do
      Hubspot.search_contacts_by_id(
        fn _, path, _, _ ->
          case path do
            "/crm/v4/objects/contacts/batch/read" ->
              pull_contacts()

            "/crm/v4/associations/contacts/companies/batch/read" ->
              %{"results" => []}
          end
        end,
        ["1", "2"]
      )
    end
  end
end
