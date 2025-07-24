defmodule Sync.Clients.Whippy.Resources.Integrations do
  @moduledoc false
  import Sync.Clients.Whippy.Common

  def create_integration(api_key, integration) do
    url = "#{get_base_url()}/v1/organization/integrations"

    api_key
    |> request(:post, url, %{
      "integration_id" => integration.id,
      "client" => integration.client,
      "name" => integration.integration
    })
    |> handle_response(fn response ->
      {:ok, response}
    end)
  end
end
