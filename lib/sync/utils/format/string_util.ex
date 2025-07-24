defmodule Sync.Utils.Format.StringUtil do
  @moduledoc """
  This module provides utility functions for formatting strings.
  """

  @doc """
  Converts a string to lowercase.
  If the input is not a string, it returns nil.
  """
  @spec downcase_or_nilify(binary() | any) :: binary() | nil
  def downcase_or_nilify(value) when is_binary(value), do: String.downcase(value)
  def downcase_or_nilify(_value), do: nil

  @doc """
  Converts a string to snake case.
  Removes double spaces, spaces at the beginning and end of the string, and replaces spaces with underscores.
  Removes exclamation marks, parentheses, and hyphens.
  If the input is not a string, it returns nil.
  """
  @spec to_snake_case(binary()) :: binary() | nil
  def to_snake_case(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(["!", "(", ")", "-"], "")
    |> String.replace(~r/\s{2,}/, " ")
    |> String.trim()
    |> String.replace(" ", "_")
  end

  def to_snake_case(_), do: nil

  @doc """
  Converts whippy name to first and last name
  """
  def parse_contact_name(nil), do: ["", ""]

  def parse_contact_name(name) do
    case String.split(name, ", ", parts: 2) do
      [last_name, first_name] ->
        [String.trim(first_name), String.trim(last_name)]

      [name] ->
        case name
             |> String.trim(",")
             |> String.split(" ", parts: 2) do
          [first_name, last_name] ->
            [String.trim(first_name), String.trim(last_name)]

          [first_name] ->
            [String.trim(first_name), nil]
        end
    end
  end

  @doc """
  Converts the list of maps which containing spaces and various capitalization
  styles into camelCase.
  """
  def to_camel_case_list(list) when is_list(list) do
    Enum.map(list, &to_camel_case_keys/1)
  end

  def to_camel_case_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      transformed_key = to_camel_case(to_string(key))
      transformed_value = transform_value(value)
      Map.put(acc, transformed_key, transformed_value)
    end)
  end

  defp to_camel_case(string) do
    string
    # Split by spaces or multiple spaces
    |> String.split(~r/\s+/)
    |> Enum.map(&String.downcase/1)
    |> Enum.with_index()
    |> Enum.map_join(fn
      # Leave the first word in lowercase
      {word, 0} -> word
      # Capitalize subsequent words
      {word, _} -> String.capitalize(word)
    end)
  end

  # Recursively transform values if they are maps or lists
  defp transform_value(value) when is_map(value), do: to_camel_case_keys(value)
  defp transform_value(value) when is_list(value), do: to_camel_case_list(value)
  defp transform_value(value), do: value
end
