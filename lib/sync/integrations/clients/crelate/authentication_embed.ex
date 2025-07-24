defmodule Sync.Integrations.Clients.Crelate.AuthenticationEmbed do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @required_attrs [
    :external_api_key,
    :whippy_api_key
  ]

  @primary_key false
  embedded_schema do
    field :external_api_key, :string
    field :whippy_api_key, :string
  end

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
