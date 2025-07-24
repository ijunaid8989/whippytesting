defmodule Sync.Integrations.Clients.Aqore.IntegrationAuthenticationEmbed do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Sync.Utils.Ecto.Changeset.Formatter

  @required_attrs [:whippy_api_key, :client_id, :client_secret, :requests_made, :base_api_url]

  @cast_attrs [:access_token] ++ @required_attrs

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:whippy_api_key, :string)
    field(:access_token, :string)
    field(:client_id, :string)
    field(:client_secret, :string)
    field(:requests_made, :integer)
    field(:base_api_url, :string)
  end

  @doc false
  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, @cast_attrs)
    |> validate_required(@required_attrs)
    |> Formatter.validate_url(:base_api_url)
  end
end
