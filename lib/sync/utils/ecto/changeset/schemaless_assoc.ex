defmodule Sync.Utils.Ecto.Changeset.SchemalessAssoc do
  @moduledoc """
  This module provides a way to create a schemaless association in an Ecto
  changeset. This is useful when you have a map with nested maps that you want to convert into
  a struct with nested structs.
  """

  @doc """
  Casts a key in a changeset to a struct. If the key is an array, it will cast each element
  in the array to a struct.

  ## Parameters
    * `changeset` - The changeset to cast the key in.
    * `keys` - List of atoms or a signle atom representing the keys to cast.
    * `cast_to` - An atom representing the module which exposes a `to_struct!/1` function or a tuple with the first
                  element being `:array` and the second element being the module.

  ## Examples
  ```elixir
  iex> changeset = Ecto.Changeset.cast(%{}, %{address: %{street1: "123 Main St", city: "Springfield"}})
  iex> changeset = SchemalessAssoc.cast(changeset, :address, Address)
  iex> %{address: %Address{street1: "123 Main St", city: "Springfield"}} = Ecto.Changeset.apply_changes(changeset)
  ```
  """
  @type keys_or_key :: atom() | [atom()]
  @type cast_to :: atom() | {:array, atom()}
  @spec cast(Ecto.Changeset.t(), keys_or_key, cast_to) :: Ecto.Changeset.t() | no_return()
  def cast(changeset, keys, cast_to) when is_list(keys) do
    Enum.reduce(keys, changeset, fn key, acc ->
      cast(acc, key, cast_to)
    end)
  end

  def cast(changeset, key, cast_to) do
    case Ecto.Changeset.get_change(changeset, key) do
      nil -> changeset
      value -> do_cast(changeset, key, cast_to, value)
    end
  end

  # Pattern matching for the cast_to argument to determine if the value should be cast to an array of structs
  defp do_cast(changeset, key, {:array, module}, value),
    do: Ecto.Changeset.put_change(changeset, key, Enum.map(value, &module.to_struct!/1))

  defp do_cast(changeset, key, module, value), do: Ecto.Changeset.put_change(changeset, key, module.to_struct!(value))
end
