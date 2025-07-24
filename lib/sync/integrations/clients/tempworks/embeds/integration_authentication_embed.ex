defmodule Sync.Integrations.Clients.Tempworks.IntegrationAuthenticationEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @default_scope "assignment-read contact-write customer-read employee-write offline_access openid order-read profile"
  @default_token_type "Bearer"

  @required_attrs [
    :acr_values,
    :client_id,
    :client_secret,
    :whippy_api_key
  ]

  @cast_attrs [
                :access_token,
                :expires_in,
                :refresh_token,
                :token_expires_at,
                :scope,
                :token_type
              ] ++ @required_attrs

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :access_token, :string
    field :acr_values, :string
    field :client_id, :string
    field :client_secret, :string
    field :expires_in, :integer
    field :refresh_token, :string
    field :scope, :string, default: @default_scope
    field :token_expires_at, :integer
    field :token_type, :string, default: @default_token_type
    field :whippy_api_key, :string
  end

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
  end
end
