defmodule Sync.Clients.Hubspot.Resources.Contact do
  @moduledoc false
  alias Sync.Clients.Hubspot.Parser

  @api_path "/crm/v4"
  @list_contacts_path @api_path <> "/objects/contacts"
  @batch_read_path @api_path <> "/objects/contacts/batch/read"
  @batch_create_path @api_path <> "/objects/contacts/batch/create"
  @batch_read_associations_path @api_path <> "/associations/contacts/companies/batch/read"
  @limit 100

  def pull_contacts(client, cursor \\ "") do
    params = build_params(cursor)

    result =
      :get
      |> client.(
        @list_contacts_path <>
          "?" <>
          URI.encode_query(params),
        %{},
        false
      )
      |> process_contacts_response()

    case result do
      {:ok, contacts, cursor} ->
        contacts = get_contacts_with_companies(client, contacts)

        {:ok, contacts, cursor}

      {:ok, contacts} ->
        contacts = get_contacts_with_companies(client, contacts)
        {:ok, contacts}
    end
  end

  def search_contacts_by_id(client, ids) do
    inputs = Enum.map(ids, fn id -> %{id: id} end)

    {:ok, contacts} =
      :post
      |> client.(
        @batch_read_path,
        %{
          inputs: inputs,
          properties: ["firstname", "lastname", "email", "phone"]
        },
        false
      )
      |> process_contacts_response()

    contacts = get_contacts_with_companies(client, contacts)

    {:ok, contacts}
  end

  def push_contacts(client, contacts) do
    external_contacts =
      contacts
      |> Enum.map(&Parser.parse(:whippy_contact, &1))
      |> send_contacts!(client)
      |> Enum.map(&Parser.parse(:hubspot_contact, &1))

    match_external_id(contacts, external_contacts)
  end

  defp get_contacts_with_companies(client, contacts) do
    companies =
      :post
      |> client.(
        @batch_read_associations_path,
        %{inputs: Enum.map(contacts, fn contact -> %{id: contact.external_id} end)},
        false
      )
      |> process_contacts_associations_response()

    Enum.map(contacts, fn contact ->
      case Enum.find(companies, fn company -> company.external_contact_id == contact.external_id end) do
        nil ->
          contact

        company ->
          external_contact = Map.put(contact.external_contact, :company_id, company.company_id)
          Map.put(contact, :external_contact, external_contact)
      end
    end)
  end

  defp process_contacts_associations_response(%{"results" => associations}) do
    Enum.map(associations, fn association ->
      company_id = association["to"] |> List.first() |> Map.get("toObjectId")
      %{external_contact_id: association["from"]["id"], company_id: company_id}
    end)
  end

  defp process_contacts_response(response) do
    case response do
      %{"results" => contacts, "paging" => %{"next" => %{"after" => cursor}}} ->
        {:ok, transform_hubspot_contacts(contacts), cursor}

      %{"results" => contacts} ->
        {:ok, transform_hubspot_contacts(contacts)}
    end
  end

  defp build_params(cursor) when byte_size(cursor) > 0 do
    %{
      "limit" => @limit,
      "archived" => false,
      "properties" => "phone,email,firstname,lastname",
      "after" => cursor
    }
  end

  defp build_params(_cursor) do
    %{
      "limit" => @limit,
      "properties" => "phone,email,firstname,lastname",
      "archived" => false
    }
  end

  defp transform_hubspot_contacts(contacts) do
    Enum.map(contacts, &Parser.parse(:hubspot_contact, &1))
  end

  defp send_contacts!(contacts, client) do
    body =
      client.(
        :post,
        @batch_create_path,
        %{
          inputs: contacts
        },
        false
      )

    body["results"]
  end

  defp match_external_id(contacts, external_contacts) do
    for contact <- contacts,
        external_contact <- external_contacts,
        (contact.email != nil and contact.email == external_contact.email) or
          (contact.phone != nil and contact.phone == external_contact.phone) do
      Map.merge(Map.from_struct(contact), external_contact)
    end
  end
end
