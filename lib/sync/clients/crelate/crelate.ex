defmodule Sync.Clients.Crelate do
  @moduledoc """
    This methods serve as a wrapper to make HTTP requests to the crelate client.
  """
  alias Sync.Clients.Crelate.Resources.CrelateApi

  # defdelegate create_contact(access_token, body), to: Employee

  # defdelegate create_activity(access_token, employee_id, action_id, message_body),
  #   to: Employee

  defdelegate get_contact(id, api_key, url_mode \\ false), to: CrelateApi

  defdelegate get_contacts(api_key, opts \\ []), to: CrelateApi

  defdelegate create_contact(contact, api_key, url_mode \\ false), to: CrelateApi

  defdelegate create_bulk_contacts(contacts, api_key, url_mode \\ false), to: CrelateApi

  defdelegate create_contact_message(api_key, message_body, url_mode \\ false), to: CrelateApi

  defdelegate get_whippy_sms_id(api_key, url_mode \\ false), to: CrelateApi

  defdelegate get_modified_contacts(api_key, day, opts \\ []), to: CrelateApi
end
