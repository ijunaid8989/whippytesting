defmodule Oban.Pro.Utils do
  @moduledoc false

  alias Ecto.Changeset

  @spec encode64(term(), [:compressed | :deterministic]) :: String.t()
  def encode64(term, opts \\ [:compressed]) do
    term
    |> :erlang.term_to_binary(opts)
    |> Base.encode64(padding: false)
  end

  @spec decode64(binary(), [:safe | :used]) :: term()
  def decode64(bin, opts \\ [:safe]) do
    bin
    |> Base.decode64!(padding: false)
    |> :erlang.binary_to_term(opts)
  end

  @spec hash64(iodata()) :: String.t()
  def hash64(iodata) when is_binary(iodata) or is_list(iodata) do
    :blake2s
    |> :crypto.hash(iodata)
    |> Base.encode64(padding: false)
  end

  @spec validate_opts(list(), fun()) :: :ok | {:error, term()}
  def validate_opts(opts, validator) do
    Enum.reduce_while(opts, :ok, fn opt, acc ->
      case validator.(opt) do
        {:error, _reason} = error -> {:halt, error}
        _ -> {:cont, acc}
      end
    end)
  end

  @spec cast_period(pos_integer() | {atom(), pos_integer()}) :: pos_integer()
  def cast_period({value, unit}) do
    unit = to_string(unit)

    cond do
      unit in ~w(second seconds) -> value
      unit in ~w(minute minutes) -> value * 60
      unit in ~w(hour hours) -> value * 60 * 60
      unit in ~w(day days) -> value * 24 * 60 * 60
      true -> unit
    end
  end

  def cast_period(period), do: period

  @spec enforce_keys(Changeset.t(), map(), module()) :: Changeset.t()
  def enforce_keys(changeset, params, schema) do
    fields =
      [:fields, :virtual_fields]
      |> Enum.flat_map(&schema.__schema__/1)
      |> Enum.map(&to_string/1)

    Enum.reduce(params, changeset, fn {key, _val}, acc ->
      if to_string(key) in fields do
        acc
      else
        Changeset.add_error(acc, :base, "unknown field #{key} provided")
      end
    end)
  end

  @spec take_keys(map(), [atom()]) :: [any()]
  def take_keys(map, _keys) when map_size(map) == 0, do: []

  def take_keys(map, []) when is_map(map), do: take_keys(map, Map.keys(map))

  def take_keys(map, keys) when is_map(map) and is_list(keys) do
    keys
    |> Enum.sort()
    |> Enum.map(fn key ->
      str_key = to_string(key)
      map_val = map[key] || map[str_key]

      [str_key, inspect(map_val)]
    end)
  end

  def normalize_by(by) do
    by
    |> List.wrap()
    |> Enum.map(fn
      {key, val} -> [key, val |> List.wrap() |> Enum.sort()]
      field -> field
    end)
  end

  @spec to_exception(Changeset.t()) :: Exception.t()
  def to_exception(changeset) do
    changeset
    |> to_translated_errors()
    |> Enum.reverse()
    |> Enum.map(fn {field, message} -> ArgumentError.exception("#{field} #{message}") end)
    |> List.first()
  end

  @spec to_translated_errors(Changeset.t()) :: Keyword.t()
  def to_translated_errors(changeset) do
    changeset
    |> Changeset.traverse_errors(&translate_errors/1)
    |> Enum.map(&extract_errors/1)
    |> List.flatten()
  end

  ## Conversions

  @spec maybe_to_atom(atom() | String.t()) :: atom()
  def maybe_to_atom(key) when is_binary(key), do: String.to_existing_atom(key)
  def maybe_to_atom(key), do: key

  # Helpers

  defp translate_errors({msg, opt}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opt
      |> Keyword.get(String.to_existing_atom(key), key)
      |> to_string()
    end)
  end

  defp extract_errors({_key, val}) when is_map(val) do
    val
    |> Map.to_list()
    |> Enum.map(&extract_errors/1)
  end

  defp extract_errors({key, [message | _]}), do: {key, message}
end
