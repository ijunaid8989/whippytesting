defmodule Sync.Clients.Crelate.Resources.CrelateApi do
  @moduledoc false

  import Sync.Clients.Crelate.Common

  alias Sync.Clients.Crelate.Parser

  @spec get_contact(String.t(), String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def get_contact(id, api_key, url_mode) do
    url = "#{get_base_url(url_mode)}/contacts/#{id}?api_key=#{api_key}"

    case handle_http_get_request_and_response(url) do
      {:ok, body} ->
        Parser.parse_contact_detail(body)

      {:error, error_status, _reason} ->
        {:error, error_status}

      {:error, reason} ->
        {:error, "Failed to fetch contacts: #{reason}"}
    end
  end

  @spec get_contacts(String.t(), list()) :: {:ok, list()} | {:error, term()}
  def get_contacts(api_key, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    url_mode = Keyword.get(opts, :url_mode, false)
    url = "#{get_base_url(url_mode)}/contacts?api_key=#{api_key}&"

    case handle_http_get_request_and_response(url, limit, offset) do
      {:ok, body} ->
        {:ok, Parser.parse_contacts_detail(body)}

      {:error, error_status, _reason} ->
        {:error, error_status}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec create_contact(map(), String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def create_contact(contact, api_key, url_mode) do
    url = "#{get_base_url(url_mode)}/contacts?api_key=#{api_key}"

    case handle_http_post_request_and_response(url, contact) do
      {:ok, %{"Data" => entity_id, "Metadata" => _metadata, "Errors" => []}} ->
        {:ok, %{Id: entity_id}}

      {:error, _error_status, %{"Errors" => errors}} ->
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec create_bulk_contacts(map(), String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def create_bulk_contacts(contacts, api_key, url_mode) do
    url = "#{get_base_url(url_mode)}/contacts/bulk?api_key=#{api_key}"

    case handle_http_post_request_and_response(url, contacts) do
      {:ok, %{"Data" => entity_ids, "Metadata" => _metadata, "Errors" => []}} ->
        {:ok, entity_ids}

      {:error, _error_status, %{"Errors" => errors}} ->
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec create_contact_message(String.t(), map(), boolean()) :: {:ok, CrelateApi.t()} | {:error, term()}
  def create_contact_message(api_key, message_body, url_mode) do
    url = "#{get_base_url(url_mode)}/activities?api_key=#{api_key}"

    case handle_http_post_request_and_response(url, message_body) do
      {:ok, %{"Data" => message_id, "Metadata" => _metadata, "Errors" => []}} ->
        {:ok, %{"messageId" => message_id}}

      {:error, _error_status, %{"Errors" => errors}} ->
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_whippy_sms_id(String.t(), boolean()) :: {:ok, String.t()} | {:error, term()}
  def get_whippy_sms_id(api_key, url_mode) do
    url = "#{get_base_url(url_mode)}/activitytypes?api_key=#{api_key}"

    case handle_http_get_request_and_response(url) do
      {:ok, %{"Data" => activity_types, "Metadata" => _metadata, "Errors" => []}} ->
        get_message_id(activity_types)

      {:error, _error_status, %{"Errors" => errors}} ->
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_modified_contacts(String.t(), String.t(), list()) :: {:ok, list()} | {:error, term()}
  def get_modified_contacts(api_key, iso_day, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    url_mode = Keyword.get(opts, :url_mode, false)

    modified_after =
      iso_day
      |> Date.from_iso8601!()
      |> Date.add(-1)

    url = "#{get_base_url(url_mode)}/contacts?api_key=#{api_key}&modified_after=#{modified_after}T12:00:00Z"

    case handle_http_get_request_and_response(url, limit, offset) do
      {:ok, body} ->
        {:ok, Parser.parse_contacts_detail(body)}

      {:error, error_status, _reason} ->
        {:error, error_status}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_message_id(list()) :: {:ok, String.t()} | {:error, term()}
  defp get_message_id(activity_types) do
    activity_map = Enum.find(activity_types, fn item -> item["Name"] == "Whippy SMS" end)

    case Map.get(activity_map, "Id") do
      nil -> {:error, "Whippy SMS Id not found"}
      id -> {:ok, id}
    end
  end
end
