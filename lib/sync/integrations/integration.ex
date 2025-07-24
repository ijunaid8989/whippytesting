defmodule Sync.Integrations.Integration do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Integrations.Clients.Aqore
  alias Sync.Integrations.Clients.Avionte
  alias Sync.Integrations.Clients.Crelate
  alias Sync.Integrations.Clients.Hubspot
  alias Sync.Integrations.Clients.Loxo
  alias Sync.Integrations.Clients.Tempworks
  alias Sync.Integrations.User
  alias Sync.Utils.Ecto.Changeset

  @type t :: %__MODULE__{
          external_organization_id: String.t(),
          whippy_organization_id: String.t(),
          integration: String.t(),
          settings: map(),
          authentication: Sync.Utils.Ecto.EncryptedMap.t()
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :external_organization_id,
             :whippy_organization_id,
             :integration,
             :settings,
             :authentication,
             :inserted_at,
             :updated_at
           ]}

  @embeds %{
    "avionte_authentication" => Avionte.AuthenticationEmbed,
    "avionte_settings" => Avionte.SettingsEmbed,
    "tempworks_authentication" => Tempworks.IntegrationAuthenticationEmbed,
    "tempworks_settings" => Tempworks.SettingsEmbed,
    "loxo_authentication" => Loxo.IntegrationAuthenticationEmbed,
    "loxo_settings" => Loxo.SettingsEmbed,
    "aqore_authentication" => Aqore.IntegrationAuthenticationEmbed,
    "aqore_settings" => Aqore.SettingsEmbed,
    "hubspot_authentication" => Hubspot.IntegrationAuthenticationEmbed,
    "hubspot_settings" => Hubspot.SettingsEmbed,
    "crelate_authentication" => Crelate.AuthenticationEmbed,
    "crelate_settings" => Crelate.SettingsEmbed
  }

  @required_attrs [
    :integration,
    :authentication,
    :external_organization_id,
    :whippy_organization_id,
    :client
  ]

  @cast_attrs [:settings] ++ @required_attrs

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field :authentication, Sync.Utils.Ecto.EncryptedMap
    field :integration, :string
    field :client, Ecto.Enum, values: [:avionte, :tempworks, :loxo, :aqore, :hubspot, :crelate]
    field :settings, :map
    field :external_organization_id, :string
    field :whippy_organization_id, :string
    field :office_name, :string, virtual: true
    field :branch_id, :string, virtual: true

    has_many :users, User, foreign_key: :integration_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(configuration, attrs) do
    configuration
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
    |> cast_map(:authentication, required: true)
    |> cast_map(:settings, required: false)
  end

  def setting_changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:settings])
    |> cast_map(:settings, required: false)
  end

  defp cast_map(%Ecto.Changeset{valid?: false} = changeset, _key, _opts), do: changeset

  # Finds the embed module based on the client field and casts the map field
  # after validating it with the embed module's changeset function
  defp cast_map(changeset, key, opts) do
    client_embed =
      changeset
      |> get_field(:client)
      |> Atom.to_string()
      |> Kernel.<>("_#{key}")
      |> then(&Map.get(@embeds, &1))

    opts = Keyword.put_new(opts, :with, &client_embed.changeset/1)

    Changeset.Map.cast(changeset, key, opts)
  end
end
