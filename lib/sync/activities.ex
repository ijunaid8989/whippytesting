defmodule Sync.Activities do
  @moduledoc """
  The Activities context.
  """

  import Ecto.Query, warn: false

  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Clients.Whippy
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Repo

  require Logger

  @bulk_messages_insert_timeout :timer.seconds(30)

  @doc """
  Lists all activities (messages) that are saved in the database,
  but not synced to an external integration

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `limit` - Number of records

  ## Examples

      iex> list_whippy_messages_missing_from_external_integration(%Integration{}, 100)
      [%Activity{}]

      iex> list_whippy_messages_missing_from_external_integration(%Integration{}, 100 )
      []
  """
  @spec list_whippy_messages_missing_from_external_integration(Integration.t(), number()) ::
          [Activity.t()]
  def list_whippy_messages_missing_from_external_integration(%Integration{id: integration_id}, limit \\ 100) do
    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        is_nil(a.external_activity_id) and
        not is_nil(a.whippy_activity_id)
    )
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists all activities (messages) that are saved in the database,
  but not synced to an external integration

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `whippy_contact_id` - The Whippy contact ID to check for missing messages belonging to that contact

  ## Examples

      iex> list_whippy_contact_messages_missing_from_external_integration(%Integration{}, "whippy_contact_id")
      [%Activity{}]

      iex> list_whippy_contact_messages_missing_from_external_integration(%Integration{}, "whippy_contact_id")
      []
  """
  @spec list_whippy_contact_messages_missing_from_external_integration(
          Integration.t(),
          Ecto.UUID.t()
        ) ::
          [Activity.t()]
  def list_whippy_contact_messages_missing_from_external_integration(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        whippy_contact_id
      ) do
    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and
        a.whippy_contact_id == ^whippy_contact_id and not is_nil(a.whippy_activity_id)
    )
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all activities (messages) that are saved in the database,
  but not synced to an external integration with limit and offset.

  The result will be ordered by `whippy_inserted_at` column so the newest messages will be returned first.

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `whippy_contact_id` - The Whippy contact ID to check for missing messages belonging to that contact
    * `limit` - The limit of messages to return
    * `offset` - The offset of messages to return

  ## Examples

      iex> list_whippy_contact_messages_missing_from_external_integration(%Integration{}, "whippy_contact_id", 10, 0)
      [%Activity{}]

      iex> list_whippy_contact_messages_missing_from_external_integration(%Integration{}, "whippy_contact_id", 10, 10)
      []
  """
  @spec list_whippy_contact_messages_missing_from_external_integration(
          Integration.t(),
          Ecto.UUID.t()
        ) ::
          [Activity.t()]
  def list_whippy_contact_messages_missing_from_external_integration(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        whippy_contact_id,
        limit,
        offset
      ) do
    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and
        a.whippy_contact_id == ^whippy_contact_id and not is_nil(a.whippy_activity_id)
    )
    |> order_by(desc: :whippy_activity_inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Lists all activities (messages) that are saved in the database,
  but not synced to an external integration, but only for a specific day.

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `whippy_contact_id` - The Whippy contact ID to check for missing messages belonging to that contact
    * `day` - The day for which to check for missing messages, specified as a Date struct

  ## Examples

      iex> list_daily_whippy_contact_messages(%Integration{}, "whippy_contact_id", Date.utc_today())
      [%Activity{}]

      iex> list_daily_whippy_contact_messages(%Integration{}, "whippy_contact_id", Date.utc_today())
      []
  """
  @spec list_daily_whippy_contact_messages(Integration.t(), Ecto.UUID.t(), Date.t()) ::
          [Activity.t()]
  def list_daily_whippy_contact_messages(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        whippy_contact_id,
        day
      ) do
    datetime_day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")

    datetime_day_end =
      day
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and
        a.whippy_contact_id == ^whippy_contact_id and not is_nil(a.whippy_activity_id) and
        a.inserted_at >= ^datetime_day_start and a.inserted_at < ^datetime_day_end
    )
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all activities (messages) that are saved in the database for a specific Contact,
  but not synced to an external integration, but only for a specific day.

  We want to query for all messages with an overlap of 12 hours just in case,
  therefore we use a time span of 36 hours.

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `whippy_contact_id` - The Whippy contact ID to check for missing messages belonging to that contact
    * `day` - The day for which to check for missing messages, specified as a Date struct

  ## Examples

      iex> list_daily_whippy_contact_messages_with_timezone(%Integration{}, "whippy_contact_id", Date.utc_today())
      [%Activity{}]

      iex> list_daily_whippy_contact_messages_with_timezone(%Integration{}, "whippy_contact_id", Date.utc_today())
      []
  """
  @spec list_daily_whippy_contact_messages_with_timezone(
          Integration.t(),
          Ecto.UUID.t(),
          Date.t(),
          String.t()
        ) ::
          [Activity.t()]
  def list_daily_whippy_contact_messages_with_timezone(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        whippy_contact_id,
        day,
        timezone \\ "Etc/UTC"
      ) do
    datetime_start =
      day
      |> Date.add(-1)
      |> DateTime.new!(~T[12:00:00], timezone)

    datetime_end =
      day
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], timezone)

    shifted_date_start = DateTime.shift_zone!(datetime_start, "Etc/UTC")
    shifted_date_end = DateTime.shift_zone!(datetime_end, "Etc/UTC")

    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and
        a.whippy_contact_id == ^whippy_contact_id and not is_nil(a.whippy_activity_id) and
        a.inserted_at >= ^shifted_date_start and a.inserted_at < ^shifted_date_end
    )
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all activities (messages) that are saved in the database,
  but not synced to an external integration, but only for a specific day.

  We want to query for all messages with an overlap of 12 hours just in case,
  therefore we use a time span of 36 hours.

  ## Parameters
    * `integration` - The integration for which to check for missing messages
    * `whippy_contact_id` - The Whippy contact ID to check for missing messages belonging to that contact
    * `day` - The day for which to check for missing messages, specified as a Date struct

  ## Examples

      iex> list_daily_whippy_messages_with_timezone(%Integration{}, Date.utc_today(), 100, 0)
      [%Activity{}]

      iex> list_daily_whippy_messages_with_timezone(%Integration{}, Date.utc_today(), 100, 0)
      []
  """
  @spec list_daily_whippy_messages_with_timezone(
          Integration.t(),
          Date.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) ::
          [Activity.t()]
  def list_daily_whippy_messages_with_timezone(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        day,
        limit,
        offset,
        timezone \\ "Etc/UTC"
      ) do
    datetime_start =
      day
      |> Date.add(-4)
      |> DateTime.new!(~T[12:00:00], timezone)

    datetime_end =
      day
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], timezone)

    shifted_date_start = DateTime.shift_zone!(datetime_start, "Etc/UTC")
    shifted_date_end = DateTime.shift_zone!(datetime_end, "Etc/UTC")

    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and not is_nil(a.whippy_activity_id) and a.errors == ^%{} and
        a.whippy_activity_inserted_at >= ^shifted_date_start and
        a.whippy_activity_inserted_at < ^shifted_date_end and
        not is_nil(a.external_contact_id)
    )
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns all non-synced activities for an integration with a limit and offset.

  Used to sync missing data.
  """

  @spec list_whippy_messages(Integration.t(), non_neg_integer(), non_neg_integer()) :: [
          Activity.t()
        ]
  def list_whippy_messages(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        limit,
        offset
      ) do
    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and not is_nil(a.whippy_activity_id) and a.errors == ^%{}
    )
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Fetches a list of `Activity` records representing messages from Whippy conversations
  that have been inactive for at least 15 minutes.

  ## Parameters

    - `integration`: A `%Integration{}` struct containing the `id` and `external_organization_id`
      associated with the integration for which messages are being queried.
    - `limit`: An integer specifying the maximum number of records to retrieve.
    - `offset`: An integer specifying the number of records to skip (used for pagination).

  ## Behavior

  The function:
    1. Calculates a cutoff time, which is 15 minutes prior to the current UTC time.
    2. Queries `Activity` records associated with the given integration and external organization.
    3. Excludes conversations with activity in the last 15 minutes by:
       - Grouping records by `whippy_conversation_id`.
       - Ensuring the most recent `whippy_activity_inserted_at` timestamp is older than the cutoff time.
    4. Returns a paginated list of `Activity` records for conversations meeting the inactivity criteria,
       ordered by the most recently inserted activity within each conversation.

  ## Returns

    - A list of `%Activity{}` structs meeting the query criteria.
  """
  @spec list_whippy_messages_with_the_gap_of_inactivity(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [
          Activity.t()
        ]
  def list_whippy_messages_with_the_gap_of_inactivity(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        limit,
        offset
      ) do
    cutoff_time = cutoff_time()
    un_active_conversations_query = un_active_conversations_query(integration_id, external_organization_id, cutoff_time)

    Repo.all(
      from(a in Activity,
        join: lc in subquery(un_active_conversations_query),
        on: a.whippy_conversation_id == lc.whippy_conversation_id,
        where:
          a.integration_id == ^integration_id and a.external_organization_id == ^external_organization_id and
            is_nil(a.external_activity_id) and not is_nil(a.whippy_activity_id) and a.errors == ^%{} and
            a.whippy_activity_inserted_at <= ^cutoff_time and
            not is_nil(a.external_contact_id),
        group_by: [a.whippy_conversation_id, a.id],
        order_by: [desc: max(a.inserted_at)],
        limit: ^limit,
        offset: ^offset
      )
    )
  end

  @spec list_whippy_messages_before(
          Integration.t(),
          Date.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [
          Activity.t()
        ]
  def list_whippy_messages_before(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        date,
        timezone,
        limit,
        offset
      ) do
    shifted_date_end =
      date
      |> DateTime.new!(~T[00:00:00], timezone)
      |> DateTime.shift_zone!("Etc/UTC")

    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and
        a.external_organization_id == ^external_organization_id and
        is_nil(a.external_activity_id) and not is_nil(a.whippy_activity_id) and a.errors == ^%{} and
        a.whippy_activity_inserted_at < ^shifted_date_end and not is_nil(a.external_contact_id)
    )
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def get_activity_date(integration_id, whippy_conversation_id, external_contact_id) do
    Activity
    |> where(
      [a],
      a.integration_id == ^integration_id and a.whippy_conversation_id == ^whippy_conversation_id and
        a.external_contact_id == ^external_contact_id and is_nil(a.external_activity)
    )
    |> order_by(desc: :whippy_activity_inserted_at)
    |> select([a], a.whippy_activity_inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Saves Whippy messages to the Sync database. This step is required before syncing to
  an external integration.

  ## Parameters
    * `integration` - The integration for which to save the messages
    * `contact` - The contact to which the messages belong
    * `whippy_conversation_id` - The Whippy conversation ID to which the messages belong
    * `messages` - The messages to save

  ## Examples
      iex> message = %{
        "id" => "e84300f2-0ac0-4042-b091-aebf091182a1",
        "to" => "+12345678901",
        "from": "+19876543210",
        "body" => "hi there!",
        "user" => "User Name",
        "direction": "OUTBOUND",
        "delivery_status": "delivered",
        "contact_id" => nil
      }

      iex> save_whippy_messages(%Integration{}, %Contact{}, "whippy_conversation_id", [message])
      {:ok, [%Activity{}]}

      iex> save_whippy_messages(%Integration{}, %Contact{}, "whippy_conversation_id", [%{}])
      {:ok, []}
  """
  @spec save_whippy_messages(Integration.t(), Contact.t(), Ecto.UUID.t(), [map()]) ::
          {:ok, [Activity.t()] | []}
  def save_whippy_messages(integration, contact, whippy_conversation_id, messages) do
    external_user_id = get_external_user_id_from_messages(messages, integration)

    Repo.transaction(
      fn ->
        messages
        |> Enum.chunk_every(100)
        |> Enum.map(fn messages_chunk ->
          integration
          |> prepare_whippy_messages(contact, whippy_conversation_id, messages_chunk, external_user_id)
          |> bulk_insert_whippy_messages()
        end)
      end,
      timeout: @bulk_messages_insert_timeout
    )
  end

  defp get_external_user_id_from_messages(messages, %Integration{id: integration_id}) do
    message = List.first(messages)
    whippy_user_id = message["user_id"]

    case Integrations.get_user_by_whippy_id(integration_id, whippy_user_id) do
      nil -> nil
      user -> user.external_user_id
    end
  end

  def update_activity_synced_in_external_integration(activity, external_activity_id, external_activity) do
    activity
    |> Activity.update_changeset(%{
      external_activity_id: external_activity_id,
      external_activity: external_activity
    })
    |> Repo.update()
  end

  @spec update_activity_errors(Activity.t(), map()) ::
          {:ok, Activity.t()} | {:error, Ecto.Changeset.t()}
  def update_activity_errors(activity, errors) do
    activity
    |> Activity.error_changeset(%{errors: errors})
    |> Repo.update()
  end

  @spec update_activity_by_whippy_contact_id(String.t(), String.t(), String.t()) :: {non_neg_integer(), nil | [term()]}
  def update_activity_by_whippy_contact_id(integration_id, whippy_contact_id, external_contact_id)
      when is_binary(external_contact_id) do
    Repo.update_all(
      from(a in Activity,
        where:
          is_nil(a.external_contact_id) and a.integration_id == ^integration_id and
            a.whippy_contact_id == ^whippy_contact_id
      ),
      set: [external_contact_id: external_contact_id]
    )
  end

  def update_activity_by_whippy_contact_id(
        integration_id,
        whippy_contact_id,
        old_external_contact_id,
        new_external_contact_id
      )
      when is_binary(old_external_contact_id) and is_binary(new_external_contact_id) do
    Repo.update_all(
      from(a in Activity,
        where:
          a.external_contact_id == ^old_external_contact_id and a.integration_id == ^integration_id and
            a.whippy_contact_id == ^whippy_contact_id
      ),
      set: [external_contact_id: new_external_contact_id]
    )
  end

  def update_activity_by_whippy_contact_id_in_bulk(contacts_list) do
    external_contact_ids = Enum.map(contacts_list, & &1[:external_contact_id])
    whippy_contact_ids = Enum.map(contacts_list, & &1[:whippy_contact_id])

    integration_ids =
      Enum.map(contacts_list, fn contact ->
        contact[:integration_id] |> Ecto.UUID.cast!() |> Ecto.UUID.dump!()
      end)

    # Perform a single update_all query
    query =
      from(c in Activity,
        join:
          u in fragment(
            "SELECT unnest(?::text[]) AS external_contact_id,
          unnest(?::text[]) AS whippy_contact_id,
          unnest(?::uuid[]) AS integration_id",
            ^external_contact_ids,
            ^whippy_contact_ids,
            ^integration_ids
          ),
        on:
          is_nil(c.external_contact_id) and
            c.whippy_contact_id == u.whippy_contact_id and
            c.integration_id == u.integration_id
      )

    query
    |> update([c, u],
      set: [
        external_contact_id: field(u, :external_contact_id)
      ]
    )
    |> Repo.update_all([])
  end

  #########################
  #   Private functions   #
  #########################

  defp bulk_insert_whippy_messages(bulk_message_attrs) do
    case Repo.insert_all(Activity, bulk_message_attrs,
           on_conflict: :nothing,
           conflict_target: [:integration_id, :whippy_activity_id],
           returning: true
         ) do
      {count, activities} when count > 0 and activities != [] ->
        Contacts.bulk_insert_activity_contacts(activities)

        {:ok, activities}

      {0, []} ->
        []
    end
  end

  defp prepare_whippy_messages(
         %Integration{whippy_organization_id: whippy_organization_id, external_organization_id: external_organization_id} =
           integration,
         %Contact{} = contact,
         whippy_conversation_id,
         messages,
         external_user_id
       )
       when is_binary(whippy_organization_id) and is_binary(external_organization_id) do
    messages
    |> Enum.filter(&filter_out_messages/1)
    |> Enum.map(fn message ->
      message
      |> prepare_single_whippy_message(integration, contact, whippy_conversation_id, external_user_id)
      |> validate_whippy_message()
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp validate_whippy_message(message_attrs) do
    case Activity.insert_changeset(%Activity{}, message_attrs) do
      %Ecto.Changeset{changes: changes, valid?: true} ->
        changes

      invalid_changeset ->
        Logger.error("Invalid Activity changeset: #{inspect(invalid_changeset)}")

        nil
    end
  end

  defp prepare_single_whippy_message(message, integration, contact, whippy_conversation_id, external_user_id) do
    %Integration{
      id: integration_id,
      whippy_organization_id: whippy_organization_id,
      external_organization_id: external_organization_id
    } = integration

    %Contact{whippy_contact_id: whippy_contact_id, external_contact_id: external_contact_id} =
      contact

    whippy_user_name_or_email = get_whippy_user_name_or_email(message["user_id"], integration)

    whippy_activity_with_user = Map.put(message, "user", whippy_user_name_or_email)

    message
    |> Whippy.Parser.convert_whippy_message_to_sync_activity()
    |> Map.merge(%{
      whippy_conversation_id: whippy_conversation_id,
      whippy_activity: whippy_activity_with_user,
      whippy_contact_id: whippy_contact_id,
      external_contact_id: external_contact_id,
      integration_id: integration_id,
      whippy_organization_id: whippy_organization_id,
      external_organization_id: external_organization_id,
      external_user_id: external_user_id
    })
  end

  defp filter_out_messages(%{"type" => "imported"}), do: false

  defp filter_out_messages(%{"body" => body}) when is_nil(body) or body == "", do: false

  defp filter_out_messages(_), do: true

  defp get_whippy_user_name_or_email(nil, _integration), do: "Whippy AI"

  defp get_whippy_user_name_or_email(whippy_user_id, integration) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Whippy.list_users(api_key) do
      {:ok, %{users: users}} when users != [] ->
        user =
          Enum.find(users, fn user -> String.to_integer(user.whippy_user_id) == whippy_user_id end)

        if user do
          Logger.info("Found user name: #{user.name}")
          user.name || user.email || "Whippy AI"
        else
          "Whippy AI"
        end

      error ->
        Logger.error(
          "Trying to fetch details for Whippy user #{whippy_user_id}. Failed to list users for organization: #{integration.whippy_organization_id}. Error: #{inspect(error)}"
        )

        "Whippy AI"
    end
  end

  # Calculate the cutoff datetime for 15 minutes ago
  defp cutoff_time, do: DateTime.add(DateTime.utc_now(), -15 * 60, :second)

  defp un_active_conversations_query(integration_id, external_organization_id, cutoff_time) do
    from(a in Activity,
      where:
        a.integration_id == ^integration_id and
          a.external_organization_id == ^external_organization_id and
          is_nil(a.external_activity_id) and
          not is_nil(a.whippy_activity_id) and
          a.errors == ^%{},
      group_by: a.whippy_conversation_id,
      # # Skip conversations with activity in last 15 mins
      having: max(a.whippy_activity_inserted_at) < ^cutoff_time,
      order_by: max(a.whippy_activity_inserted_at),
      select: %{
        whippy_conversation_id: a.whippy_conversation_id,
        latest_inserted_at: max(a.whippy_activity_inserted_at),
        whippy_activity_inserted_at: max(a.whippy_activity_inserted_at)
      }
    )
  end
end
