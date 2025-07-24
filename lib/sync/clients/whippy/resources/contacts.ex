defmodule Sync.Clients.Whippy.Contacts do
  @moduledoc false

  import Sync.Clients.Whippy.Common
  import Sync.Clients.Whippy.Parser, only: [parse: 2]

  alias Sync.Clients.Whippy.Model.Address
  alias Sync.Clients.Whippy.Model.BirthDate
  alias Sync.Clients.Whippy.Model.Contact
  alias Sync.Clients.Whippy.Utils

  require Logger

  @default_timeout :timer.seconds(30)
  @create_contact_fields [
    :phone,
    :email,
    :name,
    :opt_in_to,
    :opt_in_to_all_channels,
    :external_id,
    :birth_date,
    :address,
    :integration_id,
    :payload
  ]

  @doc """
  This will list back all the contacts belonging to the organization of api key user.
  This will return an {:ok, body} or {:error, _} tuple.

  ## Arguments

  ### Options
  - limit: A number to limit the number of items returned
  - offset: A number to offset the results returned
  - name: A contact's name to additionally filter on
  - email: An email to additionally filter on
  - phone: A contact's phone number to additionally filter on
  - channel_ids: A list of ids that we'll use to additionally filter on
  - channel_phones: A list of channel phones that we'll use to additionally filter on
  - has_integration: Get contacts that have the provided integration id
  - no_integration: Get contacts that do not have the provided integration id
  """
  @type list_contacts_opt ::
          {:limit, non_neg_integer()}
          | {:offset, non_neg_integer()}
          | {:name, String.t()}
          | {:email, String.t()}
          | {:phone, String.t()}
          | {:has_integration, String.t()}
          | {:no_integration, String.t()}
          | {:channel_ids, [String.t()]}
          | {:channel_phones, [String.t()]}
          | {:created_at, [before: String.t(), after: String.t()]}
  @spec list_contacts(binary(), [list_contacts_opt]) ::
          {:ok, %{contacts: [Contact.t()]}} | {:error, term()}
  def list_contacts(api_key, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :limit,
        :offset,
        :name,
        :email,
        :phone,
        :channel_ids,
        :channel_phones,
        :created_at,
        :has_integration,
        :no_integration
      ])

    url = "#{get_base_url()}/v1/contacts"

    query_params =
      opts
      |> Utils.maybe_put_repeated_query_key(:channels, :id, Keyword.get(opts, :channel_ids))
      |> Utils.maybe_put_repeated_query_key(:channels, :phone, Keyword.get(opts, :channel_phones))

    request_opts = [params: query_params, recv_timeout: @default_timeout]

    api_key
    |> request(:get, url, "", request_opts)
    |> handle_response(&parse(&1, {:contacts, :contact}))
  end

  @doc """
  Given the api key of the organization, we'll retrieve the contact that matches the id passed in, if any exists.
  """
  @spec get_contact(binary(), binary()) :: {:ok, Contact.t()} | {:error, term()}
  def get_contact(api_key, id) do
    url = "#{get_base_url()}/v1/contacts/#{id}"

    api_key
    |> request(:get, url)
    |> handle_response(&parse(&1, :contact))
  end

  @doc """
    Create a new contact within the organization. If the phone number is already taken, we just return the
    contact and will not attempt to make any changes. This means that the function is creation only, not an upset.
    The only required field in the params is the phone number which is expected to be in E.164 format.

    Note that the opt_in_to represents the channel ids that we want the user opted into. This
    can be passed in as a list of channel ids or as a list of channel objects.
  """
  @type create_contact_params :: %{
          :phone => String.t(),
          optional(:email) => String.t(),
          optional(:name) => String.t(),
          optional(:opt_in_to) => [term()],
          optional(:opt_in_to_all_channels) => boolean(),
          optional(:external_id) => binary(),
          optional(:address) => Address.t() | nil,
          optional(:birth_date) => BirthDate.t() | nil,
          optional(:integration_id) => binary() | nil,
          optional(:payload) => map() | nil
        }
  @spec create_contact(binary(), create_contact_params()) :: term()
  def create_contact(api_key, body) do
    url = "#{get_base_url()}/v1/contacts"
    body = Map.take(body, @create_contact_fields)

    api_key
    |> request(:post, url, body)
    |> handle_response()
  end

  @type update_contact_params :: %{
          optional(:phone) => String.t(),
          optional(:email) => String.t(),
          optional(:name) => String.t()
        }
  @spec update_contact(binary(), binary(), update_contact_params()) :: term()
  def update_contact(api_key, id, body) do
    body = Map.take(body, [:phone, :email, :name, :external_id])
    url = "#{get_base_url()}/v1/contacts/#{id}"

    api_key
    |> request(:put, url, body)
    |> handle_response()
  end

  @doc """
  Bulk creates or updates contacts in an organization.
  """

  @typedoc """
  This is a map for the associated Custom Object, where each key is a CustomProperty key
  and each value is the value that should be stored for that custom property.
  """
  @upsert_option_keys [
    :address,
    :birth_date,
    :default_channel_id,
    :email,
    :language,
    :name,
    :phone,
    :properties,
    :external_id,
    :integration_id,
    :payload
  ]
  @type custom_data_properties :: map()
  @type upsert_contact_params :: %{
          address: Address.t() | nil,
          birth_date: BirthDate.t() | nil,
          default_channel_id: String.t() | nil,
          language: String.t() | nil,
          name: String.t() | nil,
          external_id: binary(),
          phone: String.t() | nil,
          email: String.t() | nil,
          properties: custom_data_properties() | nil,
          integration_id: binary() | nil
        }
  @type opt_in_to_details :: %{
          id: String.t(),
          phone: String.t()
        }
  @type custom_data :: %{
          custom_object_id: String.t(),
          resource: String.t()
        }
  @type upsert_opts :: %{
          optional(:opt_in_to_all_channels) => boolean(),
          optional(:opt_in_to) => [opt_in_to_details()],
          optional(:custom_data) => custom_data()
        }
  @spec upsert_contacts(binary(), binary(), [upsert_contact_params()], [upsert_opts()]) :: term()
  def upsert_contacts(api_key, organization_id, contacts, opts \\ [])
  def upsert_contacts(_api_key, _organization_id, [], _opts), do: {:error, :list_empty}

  def upsert_contacts(api_key, organization_id, contacts, opts) do
    url = "#{get_base_url()}/v1/contacts/upsert"

    body =
      opts
      # use the default opt in to setting if none specified
      |> Enum.into(%{opt_in_to_all_channels: true})
      # merge the options with the required list of contacts
      # disregard all keys that we don't expect
      |> Map.put(:contacts, Enum.map(contacts, &Map.take(&1, @upsert_option_keys)))
      |> Map.put(:organization_id, organization_id)

    api_key
    |> request(:post, url, body)
    |> handle_response()
  end
end
