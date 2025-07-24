defmodule Sync.Integrations.Clients.Loxo.IntegrationAuthenticationEmbed do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @required_attrs [:agency_slug, :external_api_key, :whippy_api_key]

  @cast_attrs @required_attrs

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :agency_slug, :string
    field :external_api_key, :string
    field :whippy_api_key, :string
  end

  @doc false
  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
  end
end
