defmodule Sync.Clients.Tempworks.Users do
  @moduledoc """
  Interface for interacting with Tempworks users.

  In Tempworks, users are described as Service Reps.

  TO BE DEPRECATED. All resources should be in the resources namespace for the integration client.
  """

  alias Sync.Authentication
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  require Logger

  @users_url "https://api.ontempworks.com/DataLists/ServiceReps"
  @default_list_params %{skip: 0, take: 100}

  def sync(integration) do
    case list(integration) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> Map.get("data")
        |> Enum.each(&sync_user(&1, integration))

        {:ok, integration}

      {:ok, %HTTPoison.Response{status_code: 401, body: body}} ->
        Logger.error(inspect(body))

        {:error, "Authentication error"}

      {:ok, %HTTPoison.Response{status_code: 404, body: body}} ->
        Logger.error(inspect(body))

        {:error, "Resource not found"}

      {:ok, %HTTPoison.Response{status_code: 500, body: body}} ->
        Logger.error(inspect(body))

        {:error, "Internal server error"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Unexpected response: #{status_code}. Body: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # `skip` and `take` params are required, they're like offset and limit
  def list(%Integration{} = integration, params \\ %{}) do
    query_params =
      params
      |> Map.merge(@default_list_params)
      |> URI.encode_query()

    url =
      @users_url
      |> URI.parse()
      |> URI.append_query(query_params)
      |> URI.to_string()

    case Authentication.Tempworks.get_or_regenerate_service_token(integration) do
      {:ok, token} -> HTTPoison.get(url, [{"Authorization", "Bearer #{token}"}])
      error -> error
    end
  end

  # User data looks like
  # %{
  #   "email" => nil,
  #   "isActive" => true,
  #   "phoneNumber" => 7605553344,
  #   "serviceRep" => "service-rep-slug",
  #   "serviceRepFullName" => "John Doe",
  #   "srIdent" => 42
  # }
  defp sync_user(user_data, %Integration{id: integration_id, external_organization_id: external_organization_id}) do
    # Sync user to the database
    case Integrations.get_user_by_external_id(
           integration_id,
           external_organization_id,
           user_data["srIdent"]
         ) do
      nil ->
        params = parse_user_data(user_data, integration_id, external_organization_id)

        Integrations.create_user(params)

      user ->
        params = parse_user_data(user_data, integration_id, external_organization_id)

        Integrations.update_user(user, params)
    end
  end

  defp parse_user_data(user_data, integration_id, external_organization_id) do
    %{
      email: user_data["email"],
      external_user_id: to_string(user_data["srIdent"]),
      external_organization_id: external_organization_id,
      integration_id: integration_id
    }
  end
end
