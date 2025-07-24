defmodule Sync.Utils.Ecto.Changeset.Formatter do
  @moduledoc """
  This module provides functions that help with formatting values found in Ecto changesets.
  """
  require Logger

  # Supports both 5 and 6 field cron expressions
  @cron_expression_regex ~r/^(?:(\*|(?:\*|(?:[0-9]|(?:[1-5][0-9])))\/(?:[0-9]|(?:[1-5][0-9]))|(?:[0-9]|(?:[1-5][0-9]))(?:(?:\-(?:[0-9]|(?:[1-5][0-9]))?)|(?:\,(?:[0-9]|(?:[1-5][0-9])))*))\s)?(\*|(?:\*|(?:[0-9]|(?:[1-5][0-9])))\/(?:[0-9]|(?:[1-5][0-9]))|(?:[0-9]|(?:[1-5][0-9]))(?:(?:\-(?:[0-9]|(?:[1-5][0-9]))?)|(?:\,(?:[0-9]|(?:[1-5][0-9])))*))\s(\*|(?:[0-9]|1[0-9]|2[0-3])(\/(?:[0-9]|1[0-9]|2[0-3]))?|\*\/(?:[0-9]|1[0-9]|2[0-3])|(?:[0-9]|1[0-9]|2[0-3])(?:(?:\-(?:[0-9]|1[0-9]|2[0-3]))?|(?:\,(?:[0-9]|1[0-9]|2[0-3]))*))\s(\*|\?|L(?:W|\-(?:[1-9]|(?:[12][0-9])|3[01]))?|(?:[1-9]|(?:[12][0-9])|3[01])(?:W|\/(?:[1-9]|(?:[12][0-9])|3[01]))?|(?:[1-9]|(?:[12][0-9])|3[01])(?:(?:\-(?:[1-9]|(?:[12][0-9])|3[01]))?|(?:\,(?:[1-9]|(?:[12][0-9])|3[01]))*))\s(\*|(?:[1-9]|1[012]|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:\-(?:[1-9]|1[012]|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?|(?:\,(?:[1-9]|1[012]|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))*))\s(\*|\?|[0-6](?:L|\#[1-5])?|(?:[0-6]|SUN|MON|TUE|WED|THU|FRI|SAT)(?:(?:\-(?:[0-6]|SUN|MON|TUE|WED|THU|FRI|SAT))?|(?:\,(?:[0-6]|SUN|MON|TUE|WED|THU|FRI|SAT))*))\s?(\*|(?:[1-9][0-9]{3})(?:(?:\-[1-9][0-9]{3})?|(?:\,[1-9][0-9]{3})*))?$/

  @cron_expression_error_message "Invalid cron expression"

  @url_regex ~r/(?:(?:https?|ftps?):\/\/)?[A-Za-z0-9\/\-?=%.@]+\.[A-Za-z.]+(\/|\?)?[\w\/\-&?=%+#@$*().,;'!`\b=https:\b]*(?<!\.|\,|\!|\?)/m
  @unsupported_url_error "is not supported"

  @doc """
  Downcases the values of the given keys in the changeset. If the value is not a string, it will be ignored.

  ## Arguments
    * `changeset` - The changeset to downcase the keys in.
    * `keys` - List of atoms or a single atom representing the keys to downcase.

  ## Examples
  iex> changeset = Ecto.Changeset.cast(%{}, %{email: "John.Wick@email.com"})
  iex> changeset = Formatter.downcase(changeset, :email)
  iex> Ecto.Changeset<action: nil, changes: %{email: "john.wick@email.com"}, errors: []> = changeset
  """
  @type keys_or_key :: atom() | [atom()]
  @spec downcase(Ecto.Changeset.t(), keys_or_key) :: Ecto.Changeset.t()
  def downcase(%Ecto.Changeset{} = changeset, keys) when is_list(keys) do
    Enum.reduce(keys, changeset, fn key, acc ->
      downcase(acc, key)
    end)
  end

  def downcase(%Ecto.Changeset{} = changeset, key) when is_atom(key) do
    case Ecto.Changeset.get_change(changeset, key) do
      value when is_binary(value) -> Ecto.Changeset.put_change(changeset, key, String.downcase(value))
      _non_string_value -> changeset
    end
  end

  def downcase(changeset, _key), do: changeset

  @doc """
  Formats the phone number in the given key to E.164 format. If the phone number is not valid, it will be set to nil.

  ## Arguments
    * `changeset` - The changeset to format the phone number in.
    * `phone_field` - The key in the changeset that contains the phone number.

  ## Examples
  iex> changeset = Ecto.Changeset.cast(%{}, %{phone: "555-555-5555"})
  iex> changeset = Formatter.to_e164(changeset, :phone)
  iex> Ecto.Changeset<action: nil, changes: %{phone: "+15555555555"}, errors: []> = changeset

  iex> changeset = Ecto.Changeset.cast(%{}, %{phone: "invalid phone number"})
  iex> changeset = Formatter.to_e164(changeset, :phone)
  iex> Ecto.Changeset<action: nil, changes: %{phone: nil}, errors: []> = changeset
  """
  @spec to_e164(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def to_e164(%Ecto.Changeset{} = changeset, phone_field) when is_atom(phone_field) do
    case Ecto.Changeset.get_change(changeset, phone_field) do
      nil -> changeset
      phone when is_binary(phone) -> Ecto.Changeset.put_change(changeset, phone_field, format_phone(phone))
    end
  end

  def format_phone(phone) do
    case ExPhoneNumber.parse(phone, "US") do
      {:ok, parsed_phone} -> ExPhoneNumber.format(parsed_phone, :e164)
      _error -> nil
    end
  end

  @doc """
  Validates the given key in the changeset against the cron expression regex.
  In case an invalid cron expression is found, an error will be added to the changeset.

  ## Arguments
    * `changeset` - The changeset to validate the cron expression in.
    * `key` - The key in the changeset that contains the cron expression.

  ## Examples
  iex> changeset = Ecto.Changeset.cast(%{}, %{cron_expression: "*/5 * * * *"})
  iex> changeset = Formatter.validate_cron_expression(changeset, :cron_expression)
  iex> Ecto.Changeset<action: nil, changes: %{cron_expression: "*/5 * * * *"}, errors: []> = changeset

  iex> changeset = Ecto.Changeset.cast(%{}, %{cron_expression: "invalid cron expression"})
  iex> changeset = Formatter.validate_cron_expression(changeset, :cron_expression)
  iex> Ecto.Changeset<action: nil, changes: %{}, errors: [cron_expression: {"Invalid cron expression", []}]> = changeset
  """
  @spec validate_cron_expression(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_cron_expression(changeset, key) do
    Ecto.Changeset.validate_format(changeset, key, @cron_expression_regex, message: @cron_expression_error_message)
  end

  @spec validate_url(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_url(changeset, field) do
    url = Ecto.Changeset.get_change(changeset, field)

    case Regex.scan(@url_regex, url, capture: :first) do
      [[^url]] ->
        changeset

      captured ->
        Logger.warning("Unsupported #{field}: '#{url}' - Captured value: '#{inspect(captured)}'")

        Ecto.Changeset.add_error(changeset, field, @unsupported_url_error)
    end
  end
end
