defmodule Sync.Integrations.Clients.Avionte.AuthenticationEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @required_attrs [
    :client_id,
    :client_secret,
    :external_api_key,
    :fallback_external_user_id,
    :scope,
    :grant_type,
    :tenant,
    :whippy_api_key
  ]

  @cast_attrs [
                :access_token,
                :token_expires_in
              ] ++ @required_attrs

  @default_grant_type "client_credentials"
  @default_scope "avionte.aero.compasintegrationservice"

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :access_token, :string
    field :client_id, :string
    field :client_secret, :string
    field :external_api_key, :string
    field :fallback_external_user_id, :integer
    field :scope, :string, default: @default_scope
    field :grant_type, :string, default: @default_grant_type
    field :tenant, :string
    field :token_expires_in, :integer
    field :whippy_api_key, :string
  end

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
  end
end
