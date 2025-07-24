defmodule Sync.Clients.Whippy.Resources.Developer do
  @moduledoc false
  import Sync.Clients.Whippy.Common

  def create_application(api_key, application_name, application_description) do
    api_key
    |> request(:post, "#{get_base_url()}/v1/developers/applications", %{
      "name" => application_name,
      "description" => application_description,
      "active" => true
    })
    |> handle_response(fn response ->
      {:ok, response}
    end)
  end

  def create_developer_endpoint(api_key, application_id, event_types, url) do
    api_key
    |> request(:post, "#{get_base_url()}/v1/developers/endpoints", %{
      "developer_application_id" => application_id,
      "event_types" => event_types,
      "url" => url,
      "active" => true
    })
    |> handle_response(fn response ->
      {:ok, response}
    end)
  end
end
