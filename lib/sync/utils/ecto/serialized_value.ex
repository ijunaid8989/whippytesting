defmodule Sync.Utils.Ecto.SerializedValue do
  @moduledoc """
  Ecto type for serialized values.
  It should be used on database columns of type string or text.

  This custom type will serialize and deserialize data using Jason.
  """

  use Ecto.Type

  def type, do: :string

  @doc """
  Provides custom casting rules for params. Nothing changes here.
  We only need to handle deserialization.
  """
  def cast(:any, term), do: {:ok, term}
  def cast(term), do: {:ok, term}

  # When loading data from the database, we attempt to deserialize
  # the data. If it fails, we assume the data is already deserialized.
  def load(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, data}
    end
  end

  # When dumping data to the database, and the data is not string
  # we attempt to serialize it. If it fails we return an error.
  def dump(string) when is_binary(string), do: {:ok, string}

  def dump(value) do
    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, _} -> :error
    end
  end
end
