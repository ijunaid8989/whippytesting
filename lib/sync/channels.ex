defmodule Sync.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false

  alias Sync.Channels.Channel
  alias Sync.Repo
  alias Sync.Workers

  @bulk_channels_insert_timeout :timer.seconds(30)

  @doc """
  Get a channel by its integration ID and Whippy channel ID.

  An integration can have many channels with the same Whippy channel ID,
  as we can have many-to-many associations between external and Whippy channels.

  There are 2 use cases for this:
    - for integrations that require an external channel to push data to them (e.g. TempWorks).
    For them, we only want to return one of them and use it when creating an external Contact (e.g. Employee),
    - for integrations that don't require an external channel to push data to them (e.g. Avionte).
    For them, we use this interface to determine the timezone for a message, for which we know the
    Whippy channel ID, in a simpler manner.

  ## Parameters
    * `integration_id` - The integration ID.
    * `whippy_channel_id` - The Whippy channel ID.
  """
  @spec get_integration_whippy_channel(Ecto.UUID.t(), Ecto.UUID.t()) :: Channel.t() | nil
  def get_integration_whippy_channel(integration_id, whippy_channel_id) do
    Channel
    |> where(
      [c],
      c.integration_id == ^integration_id and c.whippy_channel_id == ^whippy_channel_id
    )
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Get all channels for a given integration with a specific Whippy channel ID,
  which have been synced with an external channel ID and have a timezone.

  Used when determining a timezone for messages for some integrations,
  e.g TempWorks, for which we don't want to save Whippy channels automatically.

  Can be replaced with `get_integration_whippy_channels/2` if the timezone is not needed.

  ## Parameters
    * `integration_id` - The integration ID.
    * `whippy_channel_id` - The Whippy channel ID.
  """

  @spec get_integration_whippy_channels_with_timezone(Ecto.UUID.t(), Ecto.UUID.t()) :: [Channel.t()]
  def get_integration_whippy_channels_with_timezone(integration_id, whippy_channel_id) do
    Channel
    |> where(
      [c],
      c.integration_id == ^integration_id and c.whippy_channel_id == ^whippy_channel_id and
        not is_nil(c.external_channel_id) and not is_nil(c.timezone)
    )
    |> Repo.all()
  end

  @doc """
  Used for integrations whose workflow requires manually associating
  Whippy channels with eternal channels, e.g. TempWorks.

  We can have an external channel saved with a Whippy channel ID,
  but also once more without a Whippy channel ID.

  This allows us to associate it with a different Whippy channel
  without overriding the existing association.

  This function returns only external channels available to be associated with a new Whippy channel.
  """

  @spec get_available_external_integration_channel(Ecto.UUID.t(), String.t()) :: Channel.t() | nil
  def get_available_external_integration_channel(integration_id, external_channel_id) do
    Channel
    |> where(
      [c],
      c.integration_id == ^integration_id and c.external_channel_id == ^external_channel_id and
        is_nil(c.whippy_channel_id)
    )
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  This function retrieves whippy channel id from channels
   ## Parameters
    * `integration_id` - The integration ID.
    * `external_channel_id` - The external channel ID.
  """

  def get_whippy_channel_id(integration_id, external_channel_id) do
    Channel
    |> where(
      [c],
      c.integration_id == ^integration_id and c.external_channel_id == ^external_channel_id and
        not is_nil(c.whippy_channel_id)
    )
    |> select([c], c.whippy_channel_id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns the list of channels for an integration that have both whippy_channel_id
  and external_channel_id, which would mean that they are mapped.

  This is required in order to push contacts to some integrations, such as TempWorks.
  """

  @spec list_mapped_external_integration_channels(Ecto.UUID.t()) :: [Channel.t()] | []
  def list_mapped_external_integration_channels(integration_id) do
    Channel
    |> where(
      [c],
      c.integration_id == ^integration_id and not is_nil(c.external_channel_id) and not is_nil(c.whippy_channel_id)
    )
    |> Repo.all()
  end

  @doc """
  Creates a channel with both external and Whippy channel data.
  Used when creating a channel from an external record, usually
  when changing only the Whippy channel ID to associate an existing
  external channel with a new Whippy channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Saves a Whippy channel.

  ## Examples

      iex> create_whippy_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_whippy_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_whippy_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.whippy_changeset(attrs)
    |> Repo.insert()
  end

  @spec save_external_channels(Integration.t(), [map()]) ::
          {:ok, [{non_neg_integer(), nil}]}
          | {:error, any()}
          | Ecto.Multi.failure()
  def save_external_channels(integration, channels) do
    Repo.transaction(
      fn ->
        channels
        |> Enum.chunk_every(100)
        |> Enum.map(fn channels_chunk ->
          bulk_insert_external_channels(integration, channels_chunk)
        end)
      end,
      timeout: @bulk_channels_insert_timeout
    )
  end

  defp bulk_insert_external_channels(integration, channels_chunk) do
    channel_attrs =
      prepare_external_channels(
        integration.id,
        integration.external_organization_id,
        channels_chunk
      )

    Repo.insert_all(Channel, channel_attrs,
      on_conflict: {:replace, [:external_channel]},
      conflict_target: [:integration_id, :external_channel_id, :whippy_channel_id]
    )
  end

  defp prepare_external_channels(integration_id, external_organization_id, channels)
       when is_binary(external_organization_id) do
    channels
    |> Enum.map(fn channel ->
      channel_data =
        Map.merge(channel, %{
          integration_id: integration_id,
          external_organization_id: external_organization_id
        })

      case Channel.external_insert_changeset(%Channel{}, channel_data) do
        %Ecto.Changeset{changes: changes, valid?: true} ->
          changes

        _invalid_changeset ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_whippy_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_whippy_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_whippy_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.whippy_changeset(attrs)
    |> Repo.update()
  end

  @spec associate_whippy_channel(Channel.t(), String.t()) ::
          {:ok, Channel.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def associate_whippy_channel(%Channel{} = channel, whippy_channel_id) do
    channel = Repo.preload(channel, :integration)
    whippy_channel = Workers.Whippy.Reader.get_channel(channel.integration, whippy_channel_id)

    if whippy_channel do
      channel
      |> Channel.whippy_changeset(%{
        whippy_organization_id: channel.integration.whippy_organization_id,
        whippy_channel_id: whippy_channel_id,
        whippy_channel: whippy_channel,
        timezone: whippy_channel.timezone
      })
      |> Repo.update()
    else
      {:error, "Whippy channel not found"}
    end
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end
end
