defmodule Sync.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false

  alias Sync.Integrations.Integration
  alias Sync.Integrations.User
  alias Sync.Repo

  require Logger

  @bulk_users_insert_timeout :timer.seconds(30)

  @doc """
  Returns the list of Integrations for a Whippy organization.

  ## Examples

      iex> list_integrations("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%Integration{}, ...]

  """
  def list_integrations(whippy_organization_id) do
    Integration
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Gets a single integration.

  Raises `Ecto.NoResultsError` if the Integration does not exist.

  ## Examples

      iex> get_integration!(123)
      %Integration{}

      iex> get_integration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_integration!(id), do: Repo.get!(Integration, id)

  @doc """
  Gets a single integration.

  Returns `nil` if the Integration does not exist.

  ## Examples

      iex> get_integration(123)
      %Integration{}

      iex> get_integration(456)
      nil

  """
  def get_integration(id), do: Repo.get(Integration, id)

  @doc """
  Gets a single integration.
  Raises `Ecto.NoResultsError` if the Integration does not exist.
  ## Examples
      iex> get_integration!(123, "hubstpot")
      %Integration{}
      iex> get_integration!(456, :wrong_client)
      ** (Ecto.NoResultsError)
  """
  def get_integration!(organization_id, client) do
    Integration
    |> where([i], i.whippy_organization_id == ^organization_id and i.client == ^client)
    |> limit(1)
    |> Repo.one!()
  end

  @doc """
  Gets a single integration.
  Returns `nil` if the Integration does not exist.
  ## Examples
      iex> get_integration("123", :hubspot)
      %Integration{}
      iex> get_integration("123", :wrong_client)
      nil
  """
  def get_integration(organization_id, client) do
    Integration
    |> where([i], i.whippy_organization_id == ^organization_id and i.client == ^client)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets a single integration by external organization id.
  Raises `Ecto.NoResultsError` if the Integration does not exist.
  ## Examples
      iex> get_integration_by_external_organization_id!(123, "hubstpot")
      %Integration{}
      iex> get_integration_by_external_organization_id!(456, :wrong_client)
      ** (Ecto.NoResultsError)
  """
  def get_integration_by_external_organization_id!(external_organization_id, client) do
    Integration
    |> where([i], i.external_organization_id == ^external_organization_id and i.client == ^client)
    |> limit(1)
    |> Repo.one!()
  end

  @doc """
  Gets a single integration by external organization_id.
  Returns `nil` if the Integration does not exist.
  ## Examples
      iex> get_integration_by_external_organization_id("123", :hubspot)
      %Integration{}
      iex> get_integration_by_external_organization_id("123", :wrong_client)
      nil
  """
  def get_integration_by_external_organization_id(external_organization_id, client) do
    Integration
    |> where([i], i.external_organization_id == ^external_organization_id and i.client == ^client)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates an integration.

  ## Examples

      iex> create_integration(%{field: value})
      {:ok, %Integration{}}

      iex> create_integration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_integration(attrs \\ %{}) do
    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an integration.

  ## Examples

      iex> update_integration(integration, %{field: new_value})
      {:ok, %Integration{}}

      iex> update_integration(integration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_integration(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an integration settings.

  ## Examples

      iex> update_integration_settings(integration, %{field: new_value})
      {:ok, %Integration{}}

      iex> update_integration_settings(integration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_integration_settings(%Integration{} = integration, attrs) do
    integration
    |> Integration.setting_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an integration.

  ## Examples

      iex> delete_integration(integration)
      {:ok, %Integration{}}

      iex> delete_integration(integration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_integration(%Integration{} = integration) do
    Repo.delete(integration)
  end

  @doc """
  Returns the list of Users for a Whippy organization.

  ## Examples

      iex> list_users("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%User{}, ...]

  """
  def list_users(whippy_organization_id) do
    User
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_external_id(integration_id, external_organization_id, id) when is_integer(id) do
    Repo.get_by(User,
      integration_id: integration_id,
      external_organization_id: external_organization_id,
      external_user_id: "#{id}"
    )
  end

  @spec get_user_by_external_id(Ecto.UUID.t(), binary(), binary()) :: User.t() | nil
  def get_user_by_external_id(integration_id, external_organization_id, id) when is_binary(id) do
    Repo.get_by(User,
      integration_id: integration_id,
      external_organization_id: external_organization_id,
      external_user_id: id
    )
  end

  @spec get_user_by_whippy_id(Ecto.UUID.t(), binary()) :: User.t() | nil
  def get_user_by_whippy_id(integration_id, whippy_user_id) when is_binary(whippy_user_id) do
    Repo.get_by(User,
      integration_id: integration_id,
      whippy_user_id: whippy_user_id
    )
  end

  @spec get_user_by_whippy_id(Ecto.UUID.t(), integer()) :: User.t() | nil
  def get_user_by_whippy_id(integration_id, whippy_user_id) do
    Repo.get_by(User,
      integration_id: integration_id,
      whippy_user_id: "#{whippy_user_id}"
    )
  end

  @spec get_users_by_whippy_ids(Ecto.UUID.t(), [binary()]) :: [User.t()]
  def get_users_by_whippy_ids(integration_id, whippy_user_ids) do
    Repo.all(from u in User, where: u.integration_id == ^integration_id and u.whippy_user_id in ^whippy_user_ids)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Receives a Whippy user ID and integration ID.

  Checks if the user exists. If they do, updates them,
  if not, create a new user.

  ## Examples

      iex> create_or_update_user(integration_id, whippy_user_id, %{field: value})
      {:ok, %User{}}

      iex> create_user((integration_id, whippy_user_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_or_update_user(integration_id, whippy_user_id, attrs \\ %{}) do
    case get_user_by_whippy_id(integration_id, whippy_user_id) do
      nil -> create_user(attrs)
      user -> update_user(user, attrs)
    end
  end

  @spec save_external_users(Integration.t(), [map()]) ::
          {:ok, [{non_neg_integer(), nil}]}
          | {:error, any()}
          | Ecto.Multi.failure()
  def save_external_users(integration, users) do
    Repo.transaction(
      fn ->
        users
        |> Enum.uniq_by(&Map.get(&1, :email))
        |> Enum.chunk_every(100)
        |> Enum.map(fn users_chunk ->
          user_attrs =
            prepare_external_users(
              integration.id,
              integration.external_organization_id,
              users_chunk
            )

          Repo.insert_all(User, user_attrs,
            on_conflict: {:replace, [:external_user_id, :external_organization_id]},
            conflict_target: [:integration_id, :email]
          )
        end)
      end,
      timeout: @bulk_users_insert_timeout
    )
  end

  @spec save_whippy_users(Integration.t(), [map()]) :: :ok
  def save_whippy_users(integration, users) do
    Repo.transaction(
      fn ->
        users
        |> Enum.chunk_every(100)
        |> Enum.map(fn users_chunk ->
          user_attrs =
            prepare_whippy_users(
              integration.id,
              integration.whippy_organization_id,
              users_chunk
            )

          try do
            Repo.insert_all(User, user_attrs,
              on_conflict: {:replace, [:whippy_user_id, :whippy_organization_id]},
              conflict_target: [:integration_id, :email]
            )
          rescue
            error -> {:error, "save whippy users error for integration #{integration.id}: #{inspect(error)}"}
          end
        end)
      end,
      timeout: @bulk_users_insert_timeout
    )
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Accepts a user and token data and updates the user with the token data.
  Returns the user with updated token data.
  """
  def handle_user_token_data(user, %{"id_token" => id_token} = token_data, integration)
      when is_map(token_data) and is_binary(id_token) do
    Logger.info("User token data: #{inspect(token_data)}")

    # save refresh token for user
    # calculate expires_at in UNIX time and save that too

    parsed_payload = extract_jwt_payload(id_token)
    external_user_id = parsed_payload["sub"]

    merged_authentication = Map.merge(user.authentication, token_data)

    {:ok, updated_user} =
      update_user(user, %{
        authentication: merged_authentication,
        integration_id: integration.id,
        external_organization_id: integration.external_organization_id,
        external_user_id: external_user_id
      })

    Logger.info("Updated user: #{inspect(updated_user)}")

    {:ok, updated_user}
  end

  def handle_user_token_data(_, _, _) do
    Logger.error("Invalid token data")
    {:error, "Invalid token data"}
  end

  @doc """
  Updates an integration's authentication data with the provided service token data.

  Returns {:ok, token_data} on success, {:error, reason} otherwise.
  """
  def handle_service_token_data(integration, %{"access_token" => access_token, "expires_in" => expires_in} = token_data)
      when is_map(token_data) and is_binary(access_token) do
    # Calculate the token expiration timestamp
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(expires_in, :second)
      |> DateTime.to_unix()

    # Merge the new token data with the existing authentication data
    merged_authentication =
      Map.merge(integration.authentication, Map.put(token_data, "token_expires_at", expires_at))

    # Update the integration with the merged authentication data
    update_integration(integration, %{
      authentication: merged_authentication
    })

    # {:ok, token_data}
  end

  def handle_service_token_data(_, _) do
    Logger.error("Invalid token data")
    {:error, "Invalid token data. Missing access_token or expires_in"}
  end

  @doc """
  Extracts the payload from a Json Web Token.
  """
  def extract_jwt_payload(json_web_token) when is_binary(json_web_token) do
    # Split token into parts and extract payload
    [_, payload_base64 | _] = String.split(json_web_token, ".")
    # Decode Base64 payload to raw JSON
    {:ok, raw_payload} = Base.decode64(payload_base64, strict: false)
    # Parse JSON payload to map
    {:ok, parsed_payload} = Jason.decode(raw_payload)
    parsed_payload
  end

  # Handles invalid JWT format
  def extract_jwt_payload(_) do
    Logger.error("Invalid Json Web Token")
    {:error, "Invalid Json Web Token"}
  end

  # Prepare external users for bulk insertion into sync db
  defp prepare_external_users(integration_id, external_organization_id, users) when is_binary(external_organization_id) do
    users
    |> Enum.map(fn user ->
      user_data =
        Map.merge(user, %{
          integration_id: integration_id,
          external_organization_id: external_organization_id
        })

      case User.external_changeset(%User{}, user_data) do
        %Ecto.Changeset{changes: changes, valid?: true} ->
          changes

        _invalid_changeset ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Prepare Whippy users for bulk insertion into sync db
  defp prepare_whippy_users(integration_id, whippy_organization_id, users) when is_binary(whippy_organization_id) do
    users
    |> Enum.uniq_by(& &1.whippy_user_id)
    |> Enum.map(fn user ->
      user_data =
        Map.merge(user, %{
          integration_id: integration_id,
          whippy_organization_id: whippy_organization_id
        })

      case User.whippy_changeset(%User{}, user_data) do
        %Ecto.Changeset{changes: changes, valid?: true} ->
          changes

        _invalid_changeset ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
