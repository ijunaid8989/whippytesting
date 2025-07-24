defmodule Sync.Clients.Whippy.Conversations do
  @moduledoc false

  import Sync.Clients.Whippy.Common
  import Sync.Clients.Whippy.Parser, only: [parse: 2]

  alias Sync.Clients.Whippy.Model.Conversation
  alias Sync.Clients.Whippy.Utils

  require HTTPoison
  require Logger

  @resource_name [
    :channel_ids,
    :channel_phones,
    :contact_ids,
    :contact_phones,
    :contact_emails,
    :contact_names,
    :assigned_user_ids,
    :last_message_date,
    :created_at,
    :updated_at
  ]

  @default_timeout :timer.seconds(30)

  @type get_conversation_opt ::
          {:message_limit, non_neg_integer()}
          | {:message_offset, non_neg_integer()}
          | {:messages_created_at, [before: String.t(), after: String.t()]}
  @spec get_conversation(binary(), binary(), [get_conversation_opt()]) ::
          {:ok, Conversation.t()} | {:error, term()}
  def get_conversation(api_key, id, opts \\ []) do
    url = "#{get_base_url()}/v1/conversations/#{id}"

    params =
      opts
      |> Utils.maybe_put_messages_limit(Keyword.get(opts, :message_limit))
      |> Utils.maybe_put_messages_offset(Keyword.get(opts, :message_offset))
      |> Utils.maybe_put_messages_created_at(Keyword.get(opts, :messages_created_at))
      # drop the intermediary form of some options
      |> Keyword.drop([:message_limit, :message_offset, :messages_created_at])

    api_key
    |> request(:get, url, "", params: params, options: [recv_timeout: @default_timeout])
    |> handle_response(&parse(&1, :conversation))
  end

  @doc """
  ## Arguments

  ### Options
  - statuses: An array representing the statuses to return.
      Options are [open, closed, spam, automated]
  - type: The type of conversations to return. Options are [phone, email]
  - channel_ids: An array of channel ids to return.
  - channel_phones: An array of channel phones to return.
  - contact_ids: An array of contact ids to return.
  - contact_phones: An array of contact phones to return.
  - contact_emails: An array of contact email to return.
  - contact_names: An array of contact name to return.
  - assigned_user_ids: An array of assigned user ids name to return.
  - last_message_date: An tuple representing the after and before datetime of the relevant conversations.
  - created_at: An tuple representing the after and before datetime of the relevant conversations.
  - updated_at: An tuple representing the after and before datetime of the relevant conversations.

  ## Examples
  ```elixir
  # look for conversations involving two specific contacts that was updated within a time range.
  Whippy.list_conversations(api_key,
    updated_at: [before: seven_days_ago, after: three_days_ago]
    contact_ids: [id_one, id_two]
  )
  ```
  """
  @spec list_conversations(binary(), Keyword.t()) ::
          {:ok, %{conversations: [Conversation.t()], total: non_neg_integer}} | {:error, term()}
  def list_conversations(api_key, opts \\ []) do
    url = "#{get_base_url()}/v1/conversations"

    params =
      opts
      |> Utils.maybe_put_repeated_query_key(:channels, :id, Keyword.get(opts, :channel_ids))
      |> Utils.maybe_put_repeated_query_key(:channels, :phone, Keyword.get(opts, :channel_phones))
      |> Utils.maybe_put_repeated_query_key(:contacts, :id, Keyword.get(opts, :contact_ids))
      |> Utils.maybe_put_repeated_query_key(:contacts, :phone, Keyword.get(opts, :contact_phones))
      |> Utils.maybe_put_repeated_query_key(:contacts, :email, Keyword.get(opts, :contact_emails))
      |> Utils.maybe_put_repeated_query_key(:contacts, :name, Keyword.get(opts, :contact_names))
      |> Utils.maybe_put_date_range(:last_message_date, Keyword.get(opts, :last_message_date))
      |> Utils.maybe_put_date_range(:created_at, Keyword.get(opts, :created_at))
      |> Utils.maybe_put_date_range(:updated_at, Keyword.get(opts, :updated_at))
      |> Utils.maybe_put_assigned_users(Keyword.get(opts, :assigned_user_ids))
      # remove the keys that would be added in by the Utils methods
      # for example it takes in channel_ids and updates it to channels[][id]
      |> Keyword.drop(@resource_name)

    api_key
    |> request(:get, url, "", params: params)
    |> handle_response(&parse(&1, {:conversations, :conversation}))
  end

  @doc """
  Send message to phone number
  """
  @spec send_message(String.t(), String.t(), String.t(), String.t()) :: {atom(), map()}
  def send_message(api_key, to, from, body) do
    url = "#{get_base_url()}/v1/messaging/sms"

    api_key
    |> request(:post, url, %{to: to, from: from, body: body})
    |> handle_response(&parse(&1, :send_sms))
  end
end
