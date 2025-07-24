defmodule Sync.Integrations.Clients.Hubspot.IntegrationAuthenticationEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @default_token_type "Bearer"

  @cast_attrs [
    :access_token,
    :expires_in,
    :refresh_token,
    :token_type,
    :whippy_api_key
  ]

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :access_token, :string
    field :expires_in, :integer
    field :refresh_token, :string
    field :token_type, :string, default: @default_token_type
    field :whippy_api_key, :string
  end

  @doc false
  def changeset(attrs) do
    cast(%__MODULE__{}, attrs, @cast_attrs)
  end
end
