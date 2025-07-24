defmodule Sync.Clients.Whippy do
  @moduledoc """
    This module serves as the interface to the Whippy Public API client.
  """
  alias Sync.Clients.Whippy.Channels
  alias Sync.Clients.Whippy.Contacts
  alias Sync.Clients.Whippy.Conversations
  alias Sync.Clients.Whippy.CustomObjects
  alias Sync.Clients.Whippy.Resources.Developer
  alias Sync.Clients.Whippy.Resources.Integrations
  alias Sync.Clients.Whippy.Users

  # CONTACTS
  defdelegate list_contacts(api_key, opts \\ []), to: Contacts
  defdelegate get_contact(api_key, id), to: Contacts
  defdelegate create_contact(api_key, body), to: Contacts
  defdelegate update_contact(api_key, id, body), to: Contacts
  defdelegate upsert_contacts(api_key, organization_id, contacts, opts \\ []), to: Contacts

  # CONVERSATIONS
  defdelegate get_conversation(api_key, id, opts \\ []), to: Conversations
  defdelegate list_conversations(api_key, opts \\ []), to: Conversations
  defdelegate send_message(api_key, to, from, body), to: Conversations

  # CHANNELS
  defdelegate list_channels(api_key), to: Channels
  defdelegate get_channel(api_key, channel_id), to: Channels

  # USERS
  defdelegate list_users(api_key, opts \\ []), to: Users

  # CUSTOM OBJECTS
  defdelegate list_custom_objects(api_key, opts \\ []), to: CustomObjects
  defdelegate create_custom_object(api_key, custom_object), to: CustomObjects
  defdelegate update_custom_object(api_key, custom_object_id, custom_object), to: CustomObjects
  defdelegate create_custom_property(api_key, custom_object_id, custom_property), to: CustomObjects
  defdelegate update_custom_property(api_key, custom_object_id, property_id, custom_property), to: CustomObjects
  defdelegate create_custom_object_record(api_key, custom_object_id, record), to: CustomObjects
  defdelegate update_custom_object_record(api_key, custom_object_id, record_id, record), to: CustomObjects

  # INTEGRATIONS
  defdelegate create_integration(api_key, integration), to: Integrations

  # DEVELOPER
  defdelegate create_application(api_key, application_name, application_description), to: Developer
  defdelegate create_developer_endpoint(api_key, application_id, event_types, integration_id), to: Developer
end
