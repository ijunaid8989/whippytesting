defmodule Sync.Utils.Ecto.Changeset.Map do
  @moduledoc """
  This module provides a way to validate a map field in an Ecto changeset using a custom validator and if
  the field is valid, it will cast it, otherwise it will add an error to the changeset.
  """

  @doc """
  Casts a map field in an Ecto changeset after validating it with a custom validator (changeset function).

  ## Parameters
    * `changeset` - The Ecto changeset.
    * `key` - The key of the map field in the changeset.
    * `opts` - The options for the cast operation.
      * `with` - The custom validator function that will be used to validate the map field. Expected to return an Ecto changeset.
      * `required` - A boolean indicating if the field is required or not. Defaults to `false`.

  ## Examples
      iex> changeset = Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "* * * * *"}}, [:client, :settings])
      iex> Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
      %Ecto.Changeset{
        action: nil,
        changes: %{
          client: :avionte,
          settings: %{
            daily_sync_at: "* * * * *"
          }
        }
      }

      iex> changeset = Ecto.Changeset.cast(%Integration{}, %{client: :avionte, settings: %{daily_sync_at: "invalid cron"}}, [:client, :settings])
      iex> Map.cast(changeset, :settings, with: &SettingsEmbed.changeset/1)
      %Ecto.Changeset{
        valid?: false,
        errors: [
          settings: {"daily_sync_at: Invalid cron expression", []}
        ]
      }
  """
  @type opts :: [with: function(), required: boolean()]
  @spec cast(Ecto.Changeset.t(), atom(), opts) :: Ecto.Changeset.t()
  def cast(changeset, key, opts) do
    opts = validate_opts!(opts)

    case Ecto.Changeset.get_field(changeset, key) do
      nil -> (opts[:required] && Ecto.Changeset.add_error(changeset, key, "can't be blank")) || changeset
      value -> do_cast(changeset, key, opts, value)
    end
  end

  defp do_cast(changeset, key, opts, value) do
    case opts[:with].(value) do
      %Ecto.Changeset{valid?: true} = embed_changeset ->
        changes = prepare_changes(embed_changeset)
        Ecto.Changeset.put_change(changeset, key, changes)

      %Ecto.Changeset{valid?: false, errors: [{child_key, {message, _type}} | _]} ->
        Ecto.Changeset.add_error(changeset, key, "#{child_key}: #{message}")
    end
  end

  # gets the default values, add them to changes map and converts the changes map to string based map
  defp prepare_changes(%Ecto.Changeset{data: data, changes: changes}) do
    data
    |> Map.from_struct()
    |> Map.drop(Map.keys(changes))
    |> Map.merge(changes)
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end

  defp validate_opts!(opts) do
    unless Keyword.has_key?(opts, :with) do
      raise ArgumentError, "Missing required key :with in opts"
    end

    unless is_function(opts[:with]) do
      raise ArgumentError, "The value under :with must be a function"
    end

    # Ensure these are the only keys in the opts and default the required key to false
    Keyword.validate!(opts, [:with, required: false])
  end
end
