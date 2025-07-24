defmodule Sync.Contacts do
  @moduledoc """
  The Contacts context.
  """

  import Ecto.Query

  alias Sync.Activities
  alias Sync.Channels
  alias Sync.Contacts.ActivityContact
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Contacts.CustomPropertyValue
  alias Sync.Integrations.Integration
  alias Sync.Repo
  alias Sync.Utils.Ecto.Changeset.Formatter

  require Logger

  @bulk_contacts_insert_timeout :timer.seconds(30)
  @contacts_query_timeout :timer.minutes(5)
  @unsupported_custom_property_key_symbols [
    "@",
    "#",
    "$",
    "%",
    "^",
    "&",
    "*",
    "(",
    ")",
    "+",
    "=",
    "[",
    "]",
    "{",
    "}",
    "|",
    "\\",
    ":",
    ";",
    "\"",
    "'",
    "<",
    ">",
    ",",
    ".",
    "?",
    "/",
    "!",
    "`",
    "~"
  ]

  @doc """
  Lists all contacts that are saved in the database,
  that are also synced between Whippy and an external integration.

  With limit and offset.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `limit` - The maximum number of contacts to return
    * `offset` - The number of contacts to skip

  ## Examples

      iex> list_integration_synced_contacts(%Integration{}, 100, 0)
      [%Contact{}]

      iex> list_integration_synced_contacts(%Integration{}, 100, 0)
      []
  """
  @spec list_integration_synced_contacts(Integration.t(), non_neg_integer(), non_neg_integer()) :: [Contact.t()]
  def list_integration_synced_contacts(%Integration{id: integration_id}, limit, offset) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and not is_nil(c.external_contact_id)
    )
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec list_integration_synced_contacts_without_prefixing(
          Integration.t(),
          binary(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [
          Contact.t()
        ]
  def list_integration_synced_contacts_without_prefixing(
        %Integration{id: integration_id},
        contact_prefix_pattern,
        limit,
        offset
      ) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and not is_nil(c.external_contact_id) and
        not like(c.external_contact_id, ^contact_prefix_pattern)
    )
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec list_integration_synced_contacts_with_prefixing(Integration.t(), binary(), non_neg_integer(), non_neg_integer()) ::
          [
            Contact.t()
          ]
  def list_integration_synced_contacts_with_prefixing(
        %Integration{id: integration_id},
        contact_prefix_pattern,
        limit,
        offset
      ) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and not is_nil(c.external_contact_id) and
        like(c.external_contact_id, ^contact_prefix_pattern)
    )
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec get_integration_synced_contact(Integration.t(), non_neg_integer()) :: Contact.t() | nil
  def get_integration_synced_contact(%Integration{id: integration_id}, external_contact_id) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and c.external_contact_id == ^external_contact_id
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  List the external contact IDs of contacts that are synced between Whippy and an external integration.
  """
  @spec list_integration_synced_external_contact_ids(Integration.t()) :: [binary()]
  def list_integration_synced_external_contact_ids(%Integration{id: integration_id}) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and not is_nil(c.external_contact_id)
    )
    |> select([c], c.external_contact_id)
    |> Repo.all()
  end

  @doc """
  List the external contact IDs of contacts that are synced between Whippy and an external integration,
  and are present in the provided external contact IDs list.
  """
  @spec list_integration_synced_external_contact_ids_by_external_contact_ids_list(Integration.t(), [binary()]) :: [
          binary()
        ]
  def list_integration_synced_external_contact_ids_by_external_contact_ids_list(
        %Integration{id: integration_id},
        external_contact_ids_list
      ) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.whippy_contact_id) and
        not is_nil(c.external_organization_id) and not is_nil(c.external_contact_id) and
        c.external_contact_id in ^external_contact_ids_list
    )
    |> select([c], c.external_contact_id)
    |> Repo.all(timeout: @contacts_query_timeout)
  end

  @doc """
  Lists all contacts that are saved in the database
  from an external integration, but are not yet synced in Whippy.

  With limit and offset.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `limit` - The maximum number of contacts to return
    * `offset` - The number of contacts to skip

  ## Examples

      iex> list_integration_contacts_missing_from_whippy(%Integration{}, 100, 0)
      [%Contact{}]

      iex> list_integration_contacts_missing_from_whippy(%Integration{}, 100, 0)
      []
  """
  @spec list_integration_contacts_missing_from_whippy(Integration.t(), non_neg_integer(), non_neg_integer(), term()) :: [
          Contact.t()
        ]
  def list_integration_contacts_missing_from_whippy(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        limit,
        offset,
        condition \\ dynamic(true)
      ) do
    Contact
    |> where(integration_id: ^integration_id)
    |> where(external_organization_id: ^external_organization_id)
    |> where(errors: ^%{})
    |> where([c], not is_nil(c.external_contact_id))
    |> where(^condition)
    |> where([c], is_nil(c.whippy_contact_id) or c.should_sync_to_whippy == true)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def list_integration_contacts_birth_dates_missing_from_whippy(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        limit,
        offset,
        day
      ) do
    {:ok, day} = Date.from_iso8601(day)

    # Construct the start and end of the day in UTC
    start_of_day = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(day, ~T[23:59:59], "Etc/UTC")

    Contact
    |> where(integration_id: ^integration_id)
    |> where(external_organization_id: ^external_organization_id)
    |> where(errors: ^%{})
    |> where([c], not is_nil(c.birth_date) and c.updated_at >= ^start_of_day and c.updated_at <= ^end_of_day)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Lists all contacts that are saved in the database in a specific day
  from an external integration, but are not yet synced in Whippy.

  With limit and offset.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `day` - The day to check for contacts
    * `limit` - The maximum number of contacts to return
    * `offset` - The number of contacts to skip

  ## Examples

      iex> daily_list_integration_contacts_missing_from_whippy(%Integration{}, Date.utc_today(), 100, 0)
      [%Contact{}]

      iex> daily_list_integration_contacts_missing_from_whippy(%Integration{}, Date.utc_today(), 100, 0)
      []
  """
  @spec daily_list_integration_contacts_missing_from_whippy(
          Integration.t(),
          Date.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Contact.t()]
  def daily_list_integration_contacts_missing_from_whippy(
        %Integration{id: integration_id, external_organization_id: external_organization_id},
        day,
        limit,
        offset
      ) do
    datetime_day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")

    datetime_day_end =
      day
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Contact
    |> where(integration_id: ^integration_id)
    |> where(external_organization_id: ^external_organization_id)
    |> where(errors: ^%{})
    |> where(
      [c],
      (c.inserted_at >= ^datetime_day_start and c.inserted_at < ^datetime_day_end) or
        (c.updated_at >= ^datetime_day_start and c.updated_at < ^datetime_day_end)
    )
    |> where([c], is_nil(c.whippy_contact_id) or c.should_sync_to_whippy == true)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Lists all contacts that are saved in the database from Whippy,
  but are not yet synced in an external integration.

  With limit. Note, there is no offset. Records are removed from this list
  when they are synced in an external integration, hence the offset is not needed.
  Each successful sync removes the contact from this list.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `limit` - The maximum number of contacts to return

  ## Examples

      iex> list_integration_contacts_missing_from_external_integration(%Integration{}, 100)
      [%Contact{}]

      iex> list_integration_contacts_missing_from_external_integration(%Integration{}, 100)
      []
  """
  @spec list_integration_contacts_missing_from_external_integration(
          Integration.t(),
          non_neg_integer()
        ) ::
          [Contact.t()]
  def list_integration_contacts_missing_from_external_integration(
        %Integration{id: integration_id, whippy_organization_id: whippy_organization_id},
        limit
      ) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and
        c.whippy_organization_id == ^whippy_organization_id and
        is_nil(c.external_organization_id) and c.errors == ^%{}
    )
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec list_integration_contacts_missing_from_external_integration_for_lookup(
          Integration.t(),
          non_neg_integer()
        ) ::
          [Contact.t()]
  def list_integration_contacts_missing_from_external_integration_for_lookup(
        %Integration{id: integration_id, whippy_organization_id: whippy_organization_id},
        limit
      ) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and
        c.whippy_organization_id == ^whippy_organization_id and
        is_nil(c.external_organization_id) and c.errors == ^%{} and is_nil(c.looked_up_at)
    )
    |> limit(^limit)
    |> Repo.all()
  end

  @spec list_integration_contacts_missing_birthday(
          Integration.t(),
          non_neg_integer()
        ) ::
          [Contact.t()]
  def list_integration_contacts_missing_birthday(%Integration{id: integration_id}, limit) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and (is_nil(c.birth_date) or c.birth_date == "") and
        not is_nil(c.external_contact_id)
    )
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists all contacts that are saved in the database in a specific day
  from Whippy, but are not yet synced in an external integration.

  With limit and offset.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `day` - The day to check for contacts
    * `limit` - The maximum number of contacts to return

  ## Examples

      iex> list_integration_contacts_missing_from_external_integration(%Integration{}, Date.utc_today(), 100)
      [%Contact{}]

      iex> list_integration_contacts_missing_from_external_integration(%Integration{}, Date.utc_today(), 100)
      []
  """
  @spec daily_list_integration_contacts_missing_from_external_integration(
          Integration.t(),
          Date.t(),
          non_neg_integer()
        ) :: [Contact.t()]
  def daily_list_integration_contacts_missing_from_external_integration(
        %Integration{id: integration_id, whippy_organization_id: whippy_organization_id},
        day,
        limit
      ) do
    datetime_day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")

    datetime_day_end =
      day
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and
        c.whippy_organization_id == ^whippy_organization_id and
        is_nil(c.external_organization_id) and c.inserted_at >= ^datetime_day_start and
        c.inserted_at < ^datetime_day_end
    )
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists all contacts that are synced between Whippy and an external integration, that are not yet
  converted to Custom Object Records.

  This function filters contacts associated with the given integration, ensuring that they meet specific criteria
  (e.g., presence of `whippy_contact_id` and `external_contact_id`). It excludes contacts that are already linked
  to custom object records based on the provided `custom_object_id`.

  ## Parameters
    * `integration` - The integration for which to check for synced contacts
    * `limit` - The maximum number of contacts to return
    * `custom_object_id` - The id of custom object

  ## Examples

      iex> list_contacts_not_converted_to_custom_object_records(%Integration{}, 100)
      [%Contact{}]

      iex> list_contacts_not_converted_to_custom_object_records(%Integration{}, 100)
      []
  """
  @spec list_contacts_not_converted_to_custom_object_records(Integration.t(), non_neg_integer(), String.t(), term()) ::
          [Contact.t()]
  def list_contacts_not_converted_to_custom_object_records(
        integration,
        limit,
        custom_object_id,
        condition \\ dynamic(true)
      ) do
    query =
      from c in Contact,
        left_join: cor in CustomObjectRecord,
        on:
          cor.external_custom_object_record_id == c.external_contact_id and
            cor.integration_id == ^integration.id and
            cor.custom_object_id == ^custom_object_id,
        where:
          c.integration_id == ^integration.id and
            not is_nil(c.whippy_contact_id) and
            not is_nil(c.external_contact_id) and
            is_nil(cor.id),
        where: ^condition,
        select: c,
        limit: ^limit

    Repo.all(query, timeout: @contacts_query_timeout)
  end

  @spec list_integration_contacts_by_whippy_contact_ids(Ecto.UUID.t(), [Ecto.UUID.t()]) :: [Contact.t()]
  def list_integration_contacts_by_whippy_contact_ids(integration_id, whippy_contact_ids) do
    Contact
    |> where([c], c.integration_id == ^integration_id and c.whippy_contact_id in ^whippy_contact_ids)
    |> Repo.all()
  end

  @spec get_contact_by_external_id(Ecto.UUID.t(), String.t() | nil) :: Contact.t() | nil
  def get_contact_by_external_id(_integration_id, nil), do: nil

  def get_contact_by_external_id(integration_id, external_contact_id) do
    Contact
    |> where([c], c.integration_id == ^integration_id and c.external_contact_id == ^external_contact_id)
    |> limit(1)
    |> Repo.one()
  end

  def get_contact_id_and_hash_in_bulk(integration_id, external_contact_ids) do
    Contact
    |> where([c], c.integration_id == ^integration_id and c.external_contact_id in ^external_contact_ids)
    |> select([c], %{external_contact_id: c.external_contact_id, external_contact_hash: c.external_contact_hash})
    |> Repo.all()
  end

  def get_all_external_contact_ids_in_bulk(integration_id, external_organization_id) do
    Contact
    |> where([c], c.integration_id == ^integration_id and c.external_organization_id == ^external_organization_id)
    |> select([c], c.external_contact_id)
    |> Repo.all()
  end

  def list_whippy_contact_ids_for_all_external_contact_ids(integration_id, external_contact_ids) do
    Contact
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.external_contact_id) and
        c.external_contact_id in ^external_contact_ids
    )
    |> select([c], %{
      integration_id: c.integration_id,
      external_contact_id: c.external_contact_id,
      whippy_contact_id: c.whippy_contact_id
    })
    |> Repo.all(timeout: @contacts_query_timeout)
  end

  @spec get_contact_by_whippy_id(Ecto.UUID.t(), Ecto.UUID.t() | nil) :: Contact.t() | nil
  def get_contact_by_whippy_id(_integration_id, nil), do: nil

  def get_contact_by_whippy_id(integration_id, whippy_contact_id) do
    Contact
    |> where([c], c.integration_id == ^integration_id and c.whippy_contact_id == ^whippy_contact_id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates a Contact with data from Whippy.

  ## Examples

      iex> create_whippy_contact(%{field: value})
      {:ok, %Contact{}}

      iex> create_whippy_contact(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_whippy_contact(integration_id, attrs \\ %{}) when is_binary(integration_id) do
    attrs = Map.put(attrs, :integration_id, integration_id)

    %Contact{}
    |> Contact.whippy_insert_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Sets the `looked_up_at` field for contacts that have been looked up in an external integration.

  ## Examples

      iex> update_contacts_as_looked_up(%Integration{}, [%Contact{}])
      {:ok, [{non_neg_integer(), nil}]}

      iex> update_contacts_as_looked_up(%Integration{}, [%Contact{}])
      {:error, any()}
  """
  def update_contacts_as_looked_up(integration, contacts) do
    contact_ids = Enum.map(contacts, & &1.id)

    Contact
    |> where([c], c.integration_id == ^integration.id and c.id in ^contact_ids)
    |> Repo.update_all(set: [looked_up_at: DateTime.utc_now()])
  end

  @doc """
  Creates a Contact with data from external integration.

  ## Examples

      iex> create_external_contact(%{field: value})
      {:ok, %Contact{}}

      iex> create_external_contact(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_external_contact(integration_id, attrs \\ %{}) when is_binary(integration_id) do
    attrs = Map.put(attrs, :integration_id, integration_id)

    %Contact{}
    |> Contact.external_insert_changeset(attrs)
    |> Repo.insert()
  end

  @spec save_external_contacts(Integration.t(), [map()]) ::
          {:ok, [{non_neg_integer(), nil}]}
          | {:error, any()}
          | Ecto.Multi.failure()
  def save_external_contacts(integration, contacts) do
    contacts
    |> Enum.map(&Map.update(&1, :phone, nil, fn phone -> Formatter.format_phone(phone) end))
    |> Enum.uniq_by(&Map.get(&1, :phone))
    |> Enum.chunk_every(100)
    |> Enum.map(fn contacts_chunk ->
      bulk_insert_external_contacts(integration, contacts_chunk)
    end)
  end

  defp bulk_insert_external_contacts(integration, contacts_chunk) do
    contact_attrs =
      prepare_external_contacts(
        integration.id,
        integration.external_organization_id,
        integration.whippy_organization_id,
        contacts_chunk
      )

    contact_attrs_with_hash = update_contact_with_hash(integration.id, contact_attrs)

    sync_external_contact_ids_list =
      get_all_external_contact_ids_in_bulk(integration.id, integration.external_organization_id)

    list_of_contacts_to_create =
      Enum.filter(contact_attrs_with_hash, &(&1[:external_contact_id] not in sync_external_contact_ids_list))

    list_of_contacts_to_update =
      Enum.filter(contact_attrs_with_hash, &(&1[:external_contact_id] in sync_external_contact_ids_list))

    bulk_update_contacts(list_of_contacts_to_update, integration)

    Repo.insert_all(Contact, list_of_contacts_to_create,
      on_conflict:
        {:replace,
         [
           :external_contact_id,
           :external_organization_id,
           :external_contact,
           :external_organization_entity_type,
           :birth_date,
           :address,
           :external_contact_hash,
           :should_sync_to_whippy,
           :name,
           :email,
           :updated_at
         ]},
      conflict_target: [:integration_id, :phone],
      returning: true
    )
  rescue
    error ->
      Logger.error("Bulk insert contacts error for integration #{integration.id}: #{inspect(error)}")
  end

  defp bulk_update_contacts([], _integration), do: :ok

  defp bulk_update_contacts(list_of_contacts_to_update, integration) do
    external_contact_ids = Enum.map(list_of_contacts_to_update, & &1[:external_contact_id])
    external_organization_ids = Enum.map(list_of_contacts_to_update, & &1[:external_organization_id])

    integration_ids =
      Enum.map(list_of_contacts_to_update, fn contact ->
        contact[:integration_id] |> Ecto.UUID.cast!() |> Ecto.UUID.dump!()
      end)

    external_contacts = Enum.map(list_of_contacts_to_update, & &1[:external_contact])
    names = Enum.map(list_of_contacts_to_update, & &1[:name])
    emails = Enum.map(list_of_contacts_to_update, & &1[:email])
    phones = Enum.map(list_of_contacts_to_update, & &1[:phone])
    birth_dates = Enum.map(list_of_contacts_to_update, & &1[:birth_date])
    external_contact_hashes = Enum.map(list_of_contacts_to_update, & &1[:external_contact_hash])
    should_sync_to_whippy = Enum.map(list_of_contacts_to_update, & &1[:should_sync_to_whippy])
    addresses = Enum.map(list_of_contacts_to_update, & &1[:address])
    updated_at_time = Enum.map(list_of_contacts_to_update, & &1[:updated_at])

    # Perform a single update_all query
    query =
      from(c in Contact,
        join:
          u in fragment(
            "SELECT unnest(?::text[]) AS external_contact_id,
                    unnest(?::text[]) AS external_organization_id,
                    unnest(?::uuid[]) AS integration_id,
                    unnest(?::jsonb[]) AS external_contact,
                    unnest(?::text[]) AS name,
                    unnest(?::text[]) AS email,
                    unnest(?::text[]) AS phone,
                    unnest(?::text[]) AS birth_date,
                    unnest(?::text[]) AS external_contact_hash,
                    unnest(?::boolean[]) AS should_sync_to_whippy,
                    unnest(?::jsonb[]) AS address,
                    unnest(?::timestamptz[]) AS updated_at",
            ^external_contact_ids,
            ^external_organization_ids,
            ^integration_ids,
            ^external_contacts,
            ^names,
            ^emails,
            ^phones,
            ^birth_dates,
            ^external_contact_hashes,
            ^should_sync_to_whippy,
            ^addresses,
            ^updated_at_time
          ),
        on:
          c.external_contact_id == u.external_contact_id and
            c.external_organization_id == u.external_organization_id and
            c.integration_id == u.integration_id
      )

    query
    |> update([c, u],
      set: [
        external_contact: field(u, :external_contact),
        name: field(u, :name),
        email: field(u, :email),
        phone: field(u, :phone),
        birth_date: field(u, :birth_date),
        external_contact_hash: field(u, :external_contact_hash),
        should_sync_to_whippy: field(u, :should_sync_to_whippy),
        address: field(u, :address),
        updated_at: field(u, :updated_at)
      ]
    )
    |> Repo.update_all([])
  rescue
    error ->
      external_contact_ids = Enum.map(list_of_contacts_to_update, & &1[:external_contact_id])
      Logger.error("Batch insert/update failed for integration #{integration.id}: Error: #{inspect(error)}")

      Logger.info(
        "Attempting integration #{integration.id} individual upserts for this batch. Contact IDs: #{inspect(external_contact_ids)}"
      )

      process_batch_individually(integration, list_of_contacts_to_update)
  end

  defp process_batch_individually(integration, contact_attrs) do
    Enum.map(contact_attrs, fn contact_attr ->
      case upsert_contact_single(integration, contact_attr) do
        {:ok, _contact} ->
          # Or actual ID
          {:ok, contact_attr[:external_contact_id]}

        {:error, _reason} ->
          Logger.info("Failed to upsert individual contact #{inspect(contact_attr)} for integration #{integration.id}")
          # Or other error indicator
          {:error, contact_attr[:external_contact_id]}
      end
    end)

    # You might want to filter for successful ones or return errors here
  end

  defp upsert_contact_single(integration, contact_attr) do
    # You already have `get_contact_record` and `upsert_external_contact`
    # Let's simplify `upsert_external_contact` to use the pre-prepared attributes.
    record = get_contact_record(integration, contact_attr)

    contact_with_whippy_id =
      Map.put(contact_attr, :whippy_channel_id, get_whippy_channel_id(integration.id, contact_attr))

    case record do
      nil ->
        %Contact{}
        |> Contact.external_insert_changeset(contact_with_whippy_id)
        |> Repo.insert(timeout: @contacts_query_timeout)

      _ ->
        record
        |> Contact.external_update_changeset(contact_with_whippy_id)
        |> Repo.update(timeout: @contacts_query_timeout)
    end
  rescue
    error ->
      Logger.error(
        "Error upserting single contact #{inspect(contact_attr)} for integration #{integration.id}: #{inspect(error)}"
      )

      {:error, :database_error}
  end

  def update_contact_with_hash(integration_id, contact_attrs) do
    external_contact_ids = Enum.map(contact_attrs, fn contact -> contact[:external_contact_id] end)

    external_ids_and_hash =
      get_contact_id_and_hash_in_bulk(
        integration_id,
        external_contact_ids
      )

    Enum.map(contact_attrs, fn attrs ->
      new_hash = calculate_hash(attrs[:external_contact])

      attrs =
        attrs
        |> Map.put(:external_contact_hash, new_hash)
        |> Map.put(:should_sync_to_whippy, true)
        |> Map.put(:errors, %{})

      case Enum.find(external_ids_and_hash, fn map -> map.external_contact_id == attrs.external_contact_id end) do
        nil ->
          attrs

        existing_hash_map ->
          compare_hashes(existing_hash_map.external_contact_hash, new_hash, attrs)
      end
    end)
  end

  def compare_hashes(existing_hash_map, new_hash, attrs) do
    if existing_hash_map == new_hash,
      do: %{attrs | should_sync_to_whippy: false},
      else: attrs
  end

  @spec upsert_external_contact(Integration.t(), map()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def upsert_external_contact(integration, contact) do
    record = get_contact_record(integration, contact)

    contact = Map.put(contact, :whippy_channel_id, get_whippy_channel_id(integration.id, contact))

    case record do
      nil ->
        %Contact{}
        |> Contact.external_insert_changeset(contact)
        |> Repo.insert(timeout: @contacts_query_timeout)

      _ ->
        record
        |> Contact.external_update_changeset(contact)
        |> Repo.update(timeout: @contacts_query_timeout)
    end
  end

  @spec overwrite_external_contact(Integration.t(), Contact.t(), map()) ::
          {:ok, map()}
          | {:error, atom(), map(), any()}
  def overwrite_external_contact(integration, contact_to_overwrite, params) do
    params = Map.put(params, :whippy_channel_id, get_whippy_channel_id(integration.id, params))
    changeset = Contact.external_update_changeset(contact_to_overwrite, params)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:contact, changeset)
    |> Ecto.Multi.run(:activity, fn _repo, %{contact: contact} ->
      if contact.whippy_contact_id do
        {count, _} =
          Activities.update_activity_by_whippy_contact_id(
            contact.integration_id,
            contact.whippy_contact_id,
            contact_to_overwrite.external_contact_id,
            params.external_contact_id
          )

        update_activity_contacts_by_whippy_contact_id(
          contact.whippy_contact_id,
          contact_to_overwrite.external_contact_id,
          params.external_contact_id
        )

        {:ok, count}
      else
        {:ok, :no_activities_to_update}
      end
    end)
    |> Repo.transaction()
  end

  defp get_contact_record(integration, %{phone: phone} = contact) when not is_nil(phone) do
    Contact
    |> where(
      external_contact_id: ^contact.external_contact_id,
      external_organization_id: ^integration.external_organization_id
    )
    |> or_where(integration_id: ^integration.id, phone: ^contact.phone)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one(timeout: @contacts_query_timeout)
  end

  defp get_contact_record(integration, contact) do
    Contact
    |> where(
      external_contact_id: ^contact.external_contact_id,
      external_organization_id: ^integration.external_organization_id
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one(timeout: @contacts_query_timeout)
  end

  defp prepare_external_contacts(integration_id, external_organization_id, whippy_organization_id, contacts)
       when is_binary(external_organization_id) do
    contacts
    |> Enum.map(fn contact ->
      contact_data =
        Map.merge(contact, %{
          integration_id: integration_id,
          external_organization_id: external_organization_id,
          whippy_organization_id: whippy_organization_id,
          whippy_channel_id: get_whippy_channel_id(integration_id, contact)
        })

      case Contact.external_insert_changeset(%Contact{}, contact_data) do
        %Ecto.Changeset{changes: changes, valid?: true} ->
          changes

        invalid_changeset ->
          Logger.info(
            "Invalid changeset (Integration #{integration_id}) for contact #{inspect(contact)}: #{inspect(invalid_changeset)}"
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_whippy_channel_id(integration_id, contact) do
    case Map.get(contact, :external_channel_id) do
      nil ->
        nil

      external_channel_id ->
        Channels.get_whippy_channel_id(integration_id, external_channel_id)
    end
  end

  @spec save_whippy_contacts(Integration.t(), [map()]) :: :ok
  def save_whippy_contacts(integration, contacts) do
    Repo.transaction(
      fn ->
        contacts
        |> Enum.chunk_every(100)
        |> Enum.map(fn contacts_chunk ->
          bulk_insert_whippy_contacts(integration, contacts_chunk)
        end)
      end,
      timeout: @bulk_contacts_insert_timeout
    )
  end

  defp bulk_insert_whippy_contacts(integration, contacts_chunk) do
    contact_attrs =
      prepare_whippy_contacts(
        integration.id,
        integration.whippy_organization_id,
        contacts_chunk
      )

    Repo.insert_all(Contact, contact_attrs,
      on_conflict: {:replace, [:whippy_contact_id, :whippy_organization_id, :whippy_contact]},
      conflict_target: [:integration_id, :phone]
    )
  end

  defp prepare_whippy_contacts(integration_id, whippy_organization_id, contacts) when is_binary(whippy_organization_id) do
    contacts
    |> Enum.map(fn contact ->
      contact_data =
        Map.merge(contact, %{
          integration_id: integration_id,
          whippy_organization_id: whippy_organization_id
        })

      case Contact.whippy_insert_changeset(%Contact{}, contact_data) do
        %Ecto.Changeset{changes: changes, valid?: true} ->
          changes

        _invalid_changeset ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec update_contact_synced_in_external_integration(
          Integration.t(),
          Contact.t(),
          String.t() | non_neg_integer(),
          map(),
          String.t(),
          map()
        ) :: {:ok, Contact.t()} | {:error, Ecto.Changeset.t()}
  @spec update_contact_synced_in_external_integration(
          Sync.Integrations.Integration.t(),
          Sync.Contacts.Contact.t(),
          binary() | non_neg_integer(),
          map(),
          binary()
        ) :: {:error, Ecto.Changeset.t()} | {:ok, Sync.Contacts.Contact.t()}
  def update_contact_synced_in_external_integration(
        integration,
        contact,
        external_id,
        external_contact,
        external_organization_entity_type,
        sync_contact_update_params \\ %{}
      ) do
    new_hash = calculate_hash(external_contact)

    params =
      if external_organization_entity_type == nil do
        Map.merge(
          %{
            external_organization_id: integration.external_organization_id,
            external_contact_id: "#{external_id}",
            external_contact: external_contact,
            external_contact_hash: new_hash,
            should_sync_to_whippy: true
          },
          sync_contact_update_params
        )
      else
        Map.merge(
          %{
            external_organization_id: integration.external_organization_id,
            external_contact_id: "#{external_id}",
            external_contact: external_contact,
            external_organization_entity_type: external_organization_entity_type,
            external_contact_hash: new_hash,
            should_sync_to_whippy: true
          },
          sync_contact_update_params
        )
      end

    contact
    |> Contact.external_update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, contact} ->
        Activities.update_activity_by_whippy_contact_id(
          contact.integration_id,
          contact.whippy_contact_id,
          contact.external_contact_id
        )

        update_activity_contacts_by_whippy_contact_id(contact.whippy_contact_id, contact.external_contact_id)

        {:ok, contact}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec update_contact_synced_in_whippy(Integration.t(), Contact.t(), Ecto.UUID.t(), map()) ::
          {:ok, Contact.t()} | {:error, Ecto.Changeset.t()}
  def update_contact_synced_in_whippy(integration, contact, whippy_id, whippy_contact) do
    params = %{
      whippy_organization_id: integration.whippy_organization_id,
      whippy_contact_id: whippy_id,
      whippy_contact: whippy_contact,
      should_sync_to_whippy: false
    }

    contact
    |> Contact.whippy_update_changeset(params)
    |> Repo.update()
  end

  @spec update_contact_errors(Contact.t(), map()) :: {:ok, Contact.t()} | {:error, Ecto.Changeset.t()}
  def update_contact_errors(contact, errors) do
    contact
    |> Contact.error_changeset(%{errors: errors})
    |> Repo.update()
  end

  @spec bulk_insert_activity_contacts([Activity.t()]) :: {:ok, [ActivityContact.t()]} | {:error, Ecto.Changeset.t()}
  def bulk_insert_activity_contacts(activities) do
    activity_contact_attrs = prepare_activity_contacts(activities)

    Repo.insert_all(ActivityContact, activity_contact_attrs,
      on_conflict: :nothing,
      conflict_target: [:activity_id, :whippy_contact_id, :external_contact_id]
    )
  end

  defp prepare_activity_contacts(activities) do
    Enum.map(activities, fn activity ->
      attrs = %{
        activity_id: activity.id,
        whippy_contact_id: activity.whippy_contact_id,
        external_contact_id: activity.external_contact_id
      }

      validate_activity_contact(attrs)
    end)
  end

  defp validate_activity_contact(activity_contact_attrs) do
    case ActivityContact.insert_changeset(%ActivityContact{}, activity_contact_attrs) do
      %Ecto.Changeset{changes: changes, valid?: true} ->
        changes

      invalid_changeset ->
        Logger.error("Invalid ActivityContact changeset: #{inspect(invalid_changeset)}")

        nil
    end
  end

  def update_activity_contacts_by_whippy_contact_id(whippy_contact_id, external_contact_id) do
    Repo.update_all(
      from(ac in ActivityContact,
        where:
          is_nil(ac.external_contact_id) and
            ac.whippy_contact_id == ^whippy_contact_id
      ),
      set: [external_contact_id: external_contact_id]
    )
  end

  def update_activity_contacts_by_whippy_contact_id(whippy_contact_id, old_external_contact_id, new_external_contact_id) do
    Repo.update_all(
      from(ac in ActivityContact,
        where:
          ac.external_contact_id == ^old_external_contact_id and
            ac.whippy_contact_id == ^whippy_contact_id
      ),
      set: [external_contact_id: new_external_contact_id]
    )
  end

  def update_activity_contacts_by_whippy_contact_id_in_bulk(contacts_list) do
    external_contact_ids = Enum.map(contacts_list, & &1[:external_contact_id])
    whippy_contact_ids = Enum.map(contacts_list, & &1[:whippy_contact_id])

    # Perform a single update_all query
    query =
      from(c in ActivityContact,
        join:
          u in fragment(
            "SELECT unnest(?::text[]) AS external_contact_id,
           unnest(?::text[]) AS whippy_contact_id",
            ^external_contact_ids,
            ^whippy_contact_ids
          ),
        on:
          is_nil(c.external_contact_id) and
            c.whippy_contact_id == u.whippy_contact_id
      )

    query
    |> update([c, u],
      set: [
        external_contact_id: field(u, :external_contact_id)
      ]
    )
    |> Repo.update_all([])
  end

  @doc """
  Returns a Custom Object of an integration by Whippy ID.

  ## Examples

      iex> get_custom_object_by_whippy_id("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "c2668ae5-e989-4e71-9019-e0d4fa46b121")
      %CustomObject{}

      ie> get_custom_object_by_whippy_id("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "c2668ae5-e989-4e71-9019-e0d4fa46b121")
      nil
  """
  @spec get_custom_object_by_whippy_id(Ecto.UUID.t(), Ecto.UUID.t()) :: CustomObject.t() | nil
  def get_custom_object_by_whippy_id(integration_id, whippy_custom_object_id) do
    CustomObject
    |> where(integration_id: ^integration_id)
    |> where(whippy_custom_object_id: ^whippy_custom_object_id)
    |> Repo.one()
  end

  @doc """
  Returns the list of Custom Objects for an organization.

  ## Examples

      iex> list_custom_objects("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%CustomObject{}, ...]

  """
  def list_custom_objects(whippy_organization_id) do
    CustomObject
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of Custom Objects for an integration and external entity type.

  ## Examples

      iex> list_custom_objects_by_external_entity_type(%Integration{}, "employee")
      [%CustomObject{}, ...]

  """
  def list_custom_objects_by_external_entity_type(integration, external_entity_type) do
    CustomObject
    |> where(external_entity_type: ^external_entity_type)
    |> where(integration_id: ^integration.id)
    |> where(whippy_organization_id: ^integration.whippy_organization_id)
    |> preload(:custom_properties)
    |> Repo.all()
  end

  @doc """
  Returns the list of Custom Objects for an integration that have not been synced to Whippy.
  """
  def list_custom_objects_missing_from_whippy(integration, limit, condition \\ dynamic(true)) do
    CustomObject
    |> where(integration_id: ^integration.id)
    |> where([c], is_nil(c.whippy_custom_object_id))
    |> where(^condition)
    |> where(errors: ^%{})
    |> limit(^limit)
    |> preload(:custom_properties)
    |> Repo.all()
  end

  @doc """
  Creates a Custom Object.

  ## Examples

      iex> create_custom_object(%{field: value})
      {:ok, %CustomObject{}}

      iex> create_custom_object(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_custom_object(attrs \\ %{}) do
    %CustomObject{}
    |> CustomObject.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Custom Object.

  ## Examples

      iex> update_custom_object(%CustomObject{}, %{field: value})
      {:ok, %CustomObject{}}

      iex> update_custom_object(%CustomObject{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_custom_object(custom_object, attrs) do
    custom_object
    |> CustomObject.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a sync Custom Object and its Custom Properties with data from Whippy.

  ## Arguments
    - `integration` - The integration for which to update the Custom Object
    - `custom_object` - The Custom Object to update
    - `whippy_custom_object` - The parsed custom object data from Whippy as it is returned
                               from Whippy.Parser.parse!(data, :custom_object)

  ## Examples

      iex> update_custom_object_synced_in_whippy(%Integration{}, %CustomObject{}, %{})
      {:ok, %CustomObject{}}

      iex> update_custom_object_synced_in_whippy(%Integration{}, %CustomObject{}, %{})
      {:error, %Ecto.Changeset{}}
  """
  def update_custom_object_synced_in_whippy(integration, custom_object, parsed_custom_object) do
    params = Map.put(parsed_custom_object, :whippy_organization_id, integration.whippy_organization_id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:custom_object, CustomObject.changeset(custom_object, params))
    |> Ecto.Multi.run(:custom_properties, fn _repo, %{custom_object: custom_object} ->
      whippy_custom_properties = parsed_custom_object.custom_properties
      properties = do_find_and_update_custom_properties(custom_object, whippy_custom_properties)

      {:ok, properties}
    end)
    |> Repo.transaction()
    |> handle_custom_object_transaction_result()
  end

  @doc """
  Creates a Custom Object with Custom Properties.

  ## Examples

      iex> create_custom_object_with_custom_properties(%{field: value})
      {:ok, %CustomObject{}}

      iex> create_custom_object_with_custom_properties(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_custom_object_with_custom_properties(map()) :: {:ok, CustomObject.t()} | {:error, Ecto.Changeset.t()}
  def create_custom_object_with_custom_properties(attrs \\ %{}) do
    create_or_update_custom_object = fn _repo, _changes ->
      case get_custom_object_by_whippy_id(attrs[:integration_id], attrs[:whippy_custom_object_id]) do
        nil -> create_custom_object(attrs)
        custom_object -> update_custom_object(custom_object, attrs)
      end
    end

    upsert_custom_properties = fn _repo, %{custom_object: custom_object} ->
      attrs[:custom_properties]
      |> do_create_or_update_custom_properties(custom_object)
      |> process_list_of_upsert_results()
    end

    Ecto.Multi.new()
    |> Ecto.Multi.run(:custom_object, &create_or_update_custom_object.(&1, &2))
    |> Ecto.Multi.run(:custom_properties, &upsert_custom_properties.(&1, &2))
    |> Repo.transaction()
    |> handle_custom_object_transaction_result()
  end

  @doc """
  Finds a Custom Property by Whippy key that is associated with a Custom Object.

  ## Examples

      iex> get_custom_property("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "first_name")
      %CustomProperty{}

      ie> get_custom_property("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "non_existent_key")
      nil
  """
  @spec get_custom_property(Ecto.UUID.t(), String.t()) :: CustomProperty.t() | nil
  def get_custom_property(custom_object_id, key) do
    CustomProperty
    |> where(custom_object_id: ^custom_object_id)
    |> where(
      [cp],
      fragment("?->>? = ?", field(cp, :whippy_custom_property), ^"key", ^key) or
        fragment("?->>? = ?", field(cp, :external_custom_property), ^"key", ^key)
    )
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns the list of Custom Properties for a Whippy organization.

  ## Examples

      iex> list_custom_properties("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%CustomProperty{}, ...]

  """
  def list_custom_properties(whippy_organization_id) do
    CustomProperty
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of Custom Properties for an integration that have not been synced to Whippy
  or are marked to be synced to Whippy.
  """
  def list_custom_properties_missing_from_whippy(integration, limit) do
    CustomProperty
    |> where(integration_id: ^integration.id)
    |> where([cp], (is_nil(cp.whippy_custom_property_id) and cp.errors == ^%{}) or cp.should_sync_to_whippy)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Creates a Custom Property.

  ## Examples

      iex> create_custom_property(%{field: value})
      {:ok, %CustomProperty{}}

      iex> create_custom_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_custom_property(attrs \\ %{}) do
    %CustomProperty{}
    |> CustomProperty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates multiple Custom Properties.
  If a Custom Property with the same key already exists, no changes will be applied to it.
  If one of the Custom Properties has an invalid value, the transaction will be rolled back and no
  Custom Properties will be created.

  ## Examples

      iex> create_custom_properties([%{field: value}, %{field: value}])
      {:ok, %{skip_or_create_employee_id: %CustomProperty{}, skip_or_create_employee_name: nil}}

      iex> create_custom_properties([%{field: bad_value}, %{field: value}])
     {:error, :skip_or_create_employee_address, %Ecto.Changeset{}, %{}}
  """
  def create_external_custom_properties(list_of_attrs) do
    list_of_attrs
    |> Enum.uniq_by(&get_in(&1, [:external_custom_property, :key]))
    |> Enum.reduce(Ecto.Multi.new(), &create_external_custom_properties_reducer/2)
    |> Repo.transaction()
  end

  defp create_external_custom_properties_reducer(attrs, multi) do
    key = get_in(attrs, [:external_custom_property, :key])
    custom_object_id = Map.get(attrs, :custom_object_id)
    new_hash = calculate_hash(attrs[:external_custom_property])

    Ecto.Multi.run(multi, "skip_or_upsert_#{key}", fn _repo, _changes ->
      if unsupported_key?(key) do
        {:ok, nil}
      else
        upsert_custom_property(custom_object_id, key, attrs, new_hash)
      end
    end)
  end

  defp unsupported_key?(key) do
    String.contains?(key, @unsupported_custom_property_key_symbols)
  end

  defp upsert_custom_property(custom_object_id, key, attrs, new_hash) do
    case get_custom_property(custom_object_id, key) do
      nil -> create_custom_property(attrs)
      %CustomProperty{} = custom_property -> update_if_hash_changed(custom_property, attrs, new_hash)
    end
  end

  defp update_if_hash_changed(custom_property, attrs, new_hash) do
    if custom_property.external_custom_property_hash != new_hash do
      updated_attrs =
        attrs
        |> Map.put(:should_sync_to_whippy, true)
        |> Map.put(:external_custom_property_hash, new_hash)

      update_custom_property(custom_property, updated_attrs)
    else
      {:ok, nil}
    end
  end

  @doc """
  Updates a Custom Property.

  ## Examples

      iex> update_custom_property(%CustomProperty{}, %{field: value})
      {:ok, %CustomProperty{}}

      iex> update_custom_property(%CustomProperty{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_custom_property(custom_property, attrs) do
    custom_property
    |> CustomProperty.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds a CustomObjectRecord of a CustomObject with a given external ID

  ## Examples

      iex> get_custom_object_record_by_external_id("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "c2668ae5-e989-4e71-9019-e0d4fa46b121", "1")
      %CustomObjectRecord{}

      ie> get_custom_object_record_by_external_id("e4aca030-c088-40d2-a9c9-05c157dcb1eb", "c2668ae5-e989-4e71-9019-e0d4fa46b121", "1")
      nil
  """
  @spec get_custom_object_record_by_external_id(Ecto.UUID.t(), Ecto.UUID.t(), String.t()) :: CustomObjectRecord.t() | nil
  def get_custom_object_record_by_external_id(integration_id, custom_object_id, external_custom_object_record_id) do
    CustomObjectRecord
    |> where(
      [cor],
      cor.integration_id == ^integration_id and
        cor.custom_object_id == ^custom_object_id and
        cor.external_custom_object_record_id == ^external_custom_object_record_id
    )
    |> Repo.one()
  end

  @doc """
  Returns the list of Custom Object Records for a Whippy organization.

  ## Examples

      iex> list_custom_object_records("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%CustomObjectRecord{}, ...]

  """
  def list_custom_object_records(whippy_organization_id) do
    CustomObjectRecord
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of Custom Object Records that are not synced to Whippy.

  ## Examples

      iex> list_custom_object_records_missing_from_whippy(%Integration{}, 100)
      [%CustomObjectRecord{}, ...]

      iex> list_custom_object_records_missing_from_whippy(%Integration{}, 100)
      []
  """
  @spec list_custom_object_records_missing_from_whippy(Integration.t(), non_neg_integer()) ::
          [CustomObjectRecord.t()]
  def list_custom_object_records_missing_from_whippy(integration, limit, condition \\ dynamic(true)) do
    CustomObjectRecord
    |> where(integration_id: ^integration.id)
    |> where(whippy_organization_id: ^integration.whippy_organization_id)
    |> where(^condition)
    |> where(errors: ^%{})
    |> where(
      [cor],
      not is_nil(cor.external_custom_object_record) and
        (is_nil(cor.whippy_custom_object_record_id) or cor.should_sync_to_whippy)
    )
    |> limit(^limit)
    |> preload(custom_property_values: :custom_property)
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  Returns all external IDs of Custom Object Records that are associated with the given Custom Object and Integration.

  ## Examples

      iex> list_external_ids_of_custom_object_records("e4aca030", "c2668ae5")
      ["1", "2", "3"]
  """
  @spec list_external_ids_of_custom_object_records(binary(), binary()) :: [binary()]
  def list_external_ids_of_custom_object_records(integration_id, custom_object_id) do
    CustomObjectRecord
    |> where(integration_id: ^integration_id)
    |> where(custom_object_id: ^custom_object_id)
    |> select([cor], cor.external_custom_object_record_id)
    |> Repo.all(timeout: :infinity)
  end

  @spec list_prefix_external_ids_of_custom_object_records(binary(), binary(), binary()) :: [binary()]
  def list_prefix_external_ids_of_custom_object_records(integration_id, custom_object_id, contact_prefix_pattern) do
    CustomObjectRecord
    |> where(
      [cor],
      cor.integration_id == ^integration_id and
        cor.custom_object_id == ^custom_object_id and
        like(cor.external_custom_object_record_id, ^contact_prefix_pattern)
    )
    |> select([cor], cor.external_custom_object_record_id)
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  Creates a Custom Object Record.

  ## Examples

      iex> create_custom_object_record(%{field: value})
      {:ok, %CustomObjectRecord{}}

      iex> create_custom_object_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_custom_object_record(attrs \\ %{}) do
    %CustomObjectRecord{}
    |> CustomObjectRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Custom Object Record.
  """
  def update_custom_object_record(custom_object_record, attrs) do
    custom_object_record
    |> CustomObjectRecord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Upserts a Custom Object Record with Custom Property Values.

  ## Description
  First, it attempts to find a Custom Object Record by the external ID. If it exists, it updates the record.
  While updating the record it builds a hash of the external_custom_object_record and compares it to the existing hash.
  If the hashes are different, it updates the record with the new hash and the should_sync_to_whippy flag as true.

  Second, it creates or updates the Custom Property Values for the Custom Object Record. It attempts to find a
  Custom Property Value by the custom_object_record_id and custom_property_id.
  If it exists, it updates the record. If it does not exist, it creates a new record.
  In the scenarios where a Custom Property Value is created, it sets the should_sync_to_whippy flag to true.
  This is done in order to handle the cases where a CustomProperty is added to a CustomObject after the initial sync.

  ## Examples

      iex> create_custom_object_record_with_custom_property_values(%{field: value})
      {:ok, %CustomObjectRecord{}}

      iex> create_custom_object_record_with_custom_property_values(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_custom_object_record_with_custom_property_values(map()) ::
          {:ok, CustomObjectRecord.t()} | {:error, Ecto.Changeset.t()}
  def create_custom_object_record_with_custom_property_values(attrs \\ %{}) do
    new_hash = calculate_hash(attrs[:external_custom_object_record])
    # Merge the values here.
    # Prepare the base record attributes
    record_attrs =
      attrs
      |> Map.put(:external_custom_object_record_hash, new_hash)
      |> Map.put(:should_sync_to_whippy, true)
      |> Map.put(:errors, %{})

    property_values = attrs[:custom_property_values] || []
    # Upsert the custom object record
    {:ok, custom_object_record} =
      %CustomObjectRecord{}
      |> CustomObjectRecord.changeset(record_attrs)
      |> Repo.insert(
        on_conflict: [
          set: [
            external_custom_object_record: attrs[:external_custom_object_record],
            external_custom_object_record_hash: Map.get(record_attrs, :external_custom_object_record_hash),
            should_sync_to_whippy: true,
            errors: %{},
            updated_at: DateTime.utc_now(:second)
          ]
        ],
        conflict_target: [
          :integration_id,
          :custom_object_id,
          :external_custom_object_record_id
        ],
        returning: true
      )

    # Bulk upsert all property values at once
    unless Enum.empty?(property_values) do
      property_values_with_record_id = map_custom_object_into_attrs(property_values, custom_object_record)

      Repo.insert_all(
        CustomPropertyValue,
        property_values_with_record_id,
        on_conflict:
          {:replace,
           [
             :whippy_custom_object_record_id,
             :whippy_custom_property_value_id,
             :external_custom_property_value_id,
             :whippy_custom_property_value,
             :external_custom_property_value,
             :custom_object_record_id,
             :custom_property_id,
             :whippy_custom_property_id,
             :external_custom_property_id,
             :errors,
             :updated_at
           ]},
        conflict_target: [:custom_object_record_id, :custom_property_id, :integration_id],
        timeout: :infinity
      )
    end

    # Return the record with associations preloaded
    return_value = Repo.preload(custom_object_record, [custom_property_values: :custom_property], force: true)
    {:ok, return_value}
  end

  defp map_custom_object_into_attrs(property_values, custom_object_record) do
    timestamps = DateTime.utc_now(:second)

    Enum.map(property_values, fn custom_property_value_attrs ->
      custom_property_value_attrs
      |> Map.put(:custom_object_record_id, custom_object_record.id)
      |> Map.put(:whippy_organization_id, custom_object_record.whippy_organization_id)
      |> Map.put(:integration_id, custom_object_record.integration_id)
      |> Map.put(:inserted_at, timestamps)
      |> Map.put(:updated_at, timestamps)
      |> Map.put(:errors, %{})
    end)
  end

  @doc """
  Updates a Custom Object Record with data from Whippy.
  """
  @spec update_custom_object_record_synced_in_whippy(
          Integration.t(),
          CustomObjectRecord.t(),
          String.t(),
          map()
        ) :: {:ok, CustomObjectRecord.t()} | {:error, Ecto.Changeset.t()}
  def update_custom_object_record_synced_in_whippy(
        integration,
        custom_object_record,
        whippy_id,
        whippy_custom_object_record
      ) do
    params = %{
      whippy_organization_id: integration.whippy_organization_id,
      whippy_custom_object_record_id: whippy_id,
      whippy_custom_object_record: whippy_custom_object_record,
      should_sync_to_whippy: false
    }

    Ecto.Multi.new()
    |> Ecto.Multi.update(:custom_object_record, CustomObjectRecord.changeset(custom_object_record, params))
    |> Ecto.Multi.run(:custom_property_values, fn _repo, %{custom_object_record: cor} ->
      whippy_custom_property_values = whippy_custom_object_record.custom_property_values
      values = do_find_and_update_custom_property_values(cor, whippy_custom_property_values)

      {:ok, values}
    end)
    |> Repo.transaction()
    |> handle_custom_object_record_transaction_result()
  end

  @spec update_custom_object_record_after_failure(CustomObjectrecord.t(), map()) ::
          {:ok, CustomObjectRecord.t()} | {:error, Ecto.Changeset.t()}
  def update_custom_object_record_after_failure(custom_object_record, params) do
    custom_object_record
    |> CustomObjectRecord.error_changeset(params)
    |> Repo.update()
  end

  @doc """
  Returns the a Custom Property Value for a specific Custom Object Record and Custom Property.
  """
  def get_custom_property_value(integration_id, custom_object_record_id, custom_property_id) do
    CustomPropertyValue
    |> where(
      [cpv],
      cpv.integration_id == ^integration_id and
        cpv.custom_object_record_id == ^custom_object_record_id and
        cpv.custom_property_id == ^custom_property_id
    )
    |> Repo.one()
  end

  @doc """
  Returns the list of Custom Property Values for a Whippy organization.

  ## Examples

      iex> list_custom_property_values("e4aca030-c088-40d2-a9c9-05c157dcb1eb")
      [%CustomPropertyValue{}, ...]

  """
  def list_custom_property_values(whippy_organization_id) do
    CustomPropertyValue
    |> where(whippy_organization_id: ^whippy_organization_id)
    |> Repo.all()
  end

  @doc """
  Creates a Custom Property Value.

  ## Examples

      iex> create_custom_property_value(%{field: value})
      {:ok, %CustomPropertyValue{}}

      iex> create_custom_property_value(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_custom_property_value(attrs \\ %{}) do
    %CustomPropertyValue{}
    |> CustomPropertyValue.changeset(attrs)
    |> Repo.insert()
  end

  def update_custom_property_value(custom_property_value, attrs) do
    custom_property_value
    |> CustomPropertyValue.changeset(attrs)
    |> Repo.update()
  end

  @spec calculate_hash(map() | struct()) :: String.t()
  def calculate_hash(map_or_struct) do
    :sha256
    |> :crypto.hash(Jason.encode!(map_or_struct))
    |> Base.encode64()
  end

  ###################################
  ## Custom Data Helper Functions  ##
  ###################################

  # Used to update the custom property values after a successful sync to whippy
  defp do_find_and_update_custom_property_values(custom_object_record, whippy_custom_property_values) do
    Enum.map(whippy_custom_property_values, fn whippy_custom_property_value ->
      sync_custom_property_value =
        CustomPropertyValue
        |> where(custom_object_record_id: ^custom_object_record.id)
        |> where(whippy_custom_property_id: ^whippy_custom_property_value.whippy_custom_property_id)
        |> Repo.one()

      case sync_custom_property_value do
        %CustomPropertyValue{} = record ->
          record
          |> CustomPropertyValue.changeset(whippy_custom_property_value)
          |> Repo.update()

        _ ->
          :ok
      end
    end)
  end

  # Used to update the custom properties after a successful sync to whippy
  defp do_find_and_update_custom_properties(custom_object, parsed_whippy_custom_properties) do
    Enum.map(parsed_whippy_custom_properties, fn parsed_custom_property ->
      sync_custom_property =
        get_custom_property(custom_object.id, parsed_custom_property.whippy_custom_property.key)

      case sync_custom_property do
        %CustomProperty{} = record ->
          update_custom_property(record, parsed_custom_property)

        _ ->
          :ok
      end
    end)
  end

  defp handle_custom_object_record_transaction_result({:ok, %{custom_object_record: custom_object_record}}) do
    {:ok, Repo.preload(custom_object_record, [custom_property_values: :custom_property], force: true)}
  end

  defp handle_custom_object_record_transaction_result({:error, _op_name, changeset, _changes}) do
    {:error, changeset}
  end

  defp handle_custom_object_transaction_result({:ok, %{custom_object: custom_object}}) do
    {:ok, Repo.preload(custom_object, :custom_properties, force: true)}
  end

  defp handle_custom_object_transaction_result({:error, _op_name, changeset, _changes}) do
    {:error, changeset}
  end

  defp do_create_or_update_custom_properties(custom_properties, custom_object) do
    Enum.map(custom_properties, fn custom_property_attrs ->
      custom_property_attrs =
        custom_property_attrs
        |> Map.put(:custom_object_id, custom_object.id)
        |> Map.put(:integration_id, custom_object.integration_id)
        |> Map.put(:whippy_organization_id, custom_object.whippy_organization_id)

      case Repo.get_by(CustomProperty, whippy_custom_property_id: custom_property_attrs[:whippy_custom_property_id]) do
        nil -> create_custom_property(custom_property_attrs)
        custom_property -> update_custom_property(custom_property, custom_property_attrs)
      end
    end)
  end

  @spec process_list_of_upsert_results([{:ok, term()} | {:error, Ecto.Changeset.t()}]) ::
          {:ok, [any()]} | {:error, Ecto.Changeset.t()}
  defp process_list_of_upsert_results(results) do
    case Enum.find(results, fn x -> match?({:error, _}, x) end) do
      nil -> {:ok, results}
      {:error, changeset} -> {:error, changeset}
    end
  end

  #######################################
  ## Custom Data Helper Functions End  ##
  #######################################
end
