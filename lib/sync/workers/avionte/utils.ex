defmodule Sync.Workers.Avionte.Utils do
  @moduledoc false

  @doc """
  Modifies the integration with branch specific data.
  """

  def modify_integration(_integration, nil), do: nil

  def modify_integration(integration, data) do
    integration =
      integration
      |> Map.put(:whippy_organization_id, data["organization_id"])
      |> Map.put(
        :authentication,
        integration.authentication
        |> Map.put("whippy_api_key", data["whippy_api_key"])
        |> Map.put("fallback_external_user_id", data["fallback_external_user_id"])
      )
      |> Map.put(:office_name, data["office_name"])
      |> Map.put(:branch_id, data["branch_id"])

    integration
  end
end
