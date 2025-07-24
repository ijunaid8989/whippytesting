defmodule Sync.Clients.Whippy.Utils do
  @moduledoc false

  require Logger

  def maybe_put_messages_limit(opts, nil), do: opts
  def maybe_put_messages_limit(opts, limit), do: Keyword.put(opts, String.to_atom("messages[limit]"), limit)
  def maybe_put_messages_offset(map, nil), do: map
  def maybe_put_messages_offset(opts, limit), do: Keyword.put(opts, String.to_atom("messages[offset]"), limit)

  def maybe_put_messages_created_at(opts, nil), do: opts

  def maybe_put_messages_created_at(opts, date_range) do
    before_datetime = Keyword.get(date_range, :before)
    after_datetime = Keyword.get(date_range, :after)
    maybe_put_messages_created_at(opts, before_datetime, after_datetime)
  end

  def maybe_put_messages_created_at(opts, nil, nil), do: opts

  def maybe_put_messages_created_at(opts, before_datetime, nil) do
    [{:"messages[before]", before_datetime} | opts]
  end

  def maybe_put_messages_created_at(opts, nil, after_datetime) do
    [{:"messages[after]", after_datetime} | opts]
  end

  def maybe_put_messages_created_at(opts, before_datetime, after_datetime) do
    opts ++ [{:"messages[before]", before_datetime}, {:"messages[after]", after_datetime}]
  end

  @type repeated_query_resource :: :channels | :contacts
  @type repeated_query_attributes :: :id | :phone | :email | :name
  @spec maybe_put_repeated_query_key(Keyword.t(), repeated_query_resource(), repeated_query_attributes(), term()) ::
          Keyword.t()
  def maybe_put_repeated_query_key(opts, _plural_resource_name, _attribute, nil), do: opts

  def maybe_put_repeated_query_key(opts, plural_resource_name, singular_attribute_name, values) do
    key = Atom.to_string(plural_resource_name) <> "[][" <> Atom.to_string(singular_attribute_name) <> "]"

    Enum.reduce(values, opts, fn id, acc -> [{String.to_atom(key), id} | acc] end)
  end

  @type date_range_resource :: :last_message_date | :created_at | :updated_at
  @spec maybe_put_date_range(Keyword.t(), date_range_resource(), term()) :: Keyword.t()
  def maybe_put_date_range(opts, _resource_name, nil), do: opts

  def maybe_put_date_range(opts, resource_name, date_range) do
    before_datetime = Keyword.get(date_range, :before)
    after_datetime = Keyword.get(date_range, :after)
    maybe_put_date_range(opts, resource_name, before_datetime, after_datetime)
  end

  def maybe_put_date_range(opts, _resource_name, nil, nil), do: opts

  def maybe_put_date_range(opts, resource_name, before_datetime, nil) do
    key = Atom.to_string(resource_name) <> "[before]"
    [{String.to_atom(key), before_datetime} | opts]
  end

  def maybe_put_date_range(opts, resource_name, nil, after_datetime) do
    key = resource_name <> "[after]"
    [{String.to_atom(key), after_datetime} | opts]
  end

  def maybe_put_date_range(opts, resource_name, before_datetime, after_datetime) do
    before_key = Atom.to_string(resource_name) <> "[before]"
    after_key = Atom.to_string(resource_name) <> "[after]"
    opts ++ [{String.to_atom(before_key), before_datetime}, {String.to_atom(after_key), after_datetime}]
  end

  def maybe_put_assigned_users(opts, nil), do: opts

  def maybe_put_assigned_users(opts, user_ids) do
    Enum.reduce(user_ids, opts, fn id, acc ->
      [{String.to_atom("assigned_users[]"), id} | acc]
    end)
  end
end
