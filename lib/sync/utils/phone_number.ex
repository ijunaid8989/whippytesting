defmodule Sync.Utils.PhoneNumber do
  @moduledoc """
  Contains functions that can be used to validate
  the format of a phone number.
  """

  require Logger

  @doc """
  Validates that the number is in e164 format.

  Due to a bug in ExPhoneNumber which leads to not recognizing US area code 983 as valid,
  we have an additional check with libphonenumbers.is_mobile_phone_valid/1.
  It is an Erlang library that is using Google's libphonenumber. Incidentally,
  ExPhoneNumber is also using it, but nevertheless, it is not working as expected.

  This is, hopefully, a temporary change until this bug is fixed in ExPhoneNumber,
  or we move to a different validation.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(phone) do
    with {:ok, parsed_phone} <- ExPhoneNumber.parse(phone, ""),
         true <- ExPhoneNumber.is_possible_number?(parsed_phone),
         true <- ExPhoneNumber.is_valid_number?(parsed_phone) or :libphonenumbers.is_mobile_phone_valid(phone) do
      true
    else
      _error ->
        short_code?(phone)
    end
  end

  @doc """
  Takes a phone number and converts it to US e164 format.
  """
  @spec format_phone(String.t()) :: String.t()
  def format_phone(phone) do
    with false <- empty?(phone),
         true <- string_with_no_letters?(phone),
         {:ok, parsed_phone} <- ExPhoneNumber.parse(phone, "US") do
      phone_number = ExPhoneNumber.format(parsed_phone, :e164)
      phone_number
    else
      _error -> ""
    end
  end

  def empty?(nil), do: true

  def empty?(""), do: true

  def empty?(_phone), do: false

  def string_with_no_letters?(phone) when is_binary(phone) do
    not Regex.match?(~r/[A-Z]|[a-z]/, phone)
  end

  def string_with_no_letters?(_phone), do: false

  def prettify_phone_number(phone) do
    case ExPhoneNumber.parse(phone, "US") do
      {:ok, parsed_phone} -> ExPhoneNumber.format(parsed_phone, :national)
      _error -> ""
    end
  end

  def short_code?(phone) do
    is_binary(phone) and byte_size(phone) in 5..7 and
      not String.starts_with?(phone, "+1")
  end

  @doc """
  Expects a changeset and checks if a phone change has been
  added to the changeset. If it has the phone is validated
  and if the phone format is not e164 an error is added to the changeset.

  Returns
  %Ecto.Changeset{}
  """
  @spec validate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate(changeset) do
    changeset
    |> Ecto.Changeset.get_change(:phone)
    |> do_validate(changeset)
  end

  defp do_validate(nil, changeset), do: changeset

  defp do_validate(phone, changeset) do
    if valid?(phone),
      do: changeset,
      else: Ecto.Changeset.add_error(changeset, :phone, "Wrong format")
  end
end
