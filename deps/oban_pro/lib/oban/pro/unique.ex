defmodule Oban.Pro.Unique do
  @moduledoc false

  alias Ecto.Changeset
  alias Oban.Job
  alias Oban.Pro.Utils

  @states_to_ints %{
    "scheduled" => 0,
    "available" => 1,
    "executing" => 2,
    "retryable" => 3,
    "completed" => 4,
    "cancelled" => 5,
    "discarded" => 6
  }

  @spec unique?(Job.changeset()) :: boolean()
  def unique?(changeset), do: match?(%{changes: %{unique: %{}}}, changeset)

  @spec with_uniq_meta(Job.changeset()) :: Job.changeset()
  def with_uniq_meta(%{changes: %{unique: %{period: _}}} = changeset) do
    uniq_meta = %{uniq: true, uniq_bmp: gen_bmp(changeset), uniq_key: gen_key(changeset)}

    meta =
      changeset
      |> Changeset.get_change(:meta, %{})
      |> Map.merge(uniq_meta)

    Changeset.put_change(changeset, :meta, meta)
  end

  def with_uniq_meta(changeset), do: changeset

  @spec gen_bmp(Job.changeset()) :: [integer()]
  def gen_bmp(%{changes: %{unique: %{states: states}}}) do
    for state <- states, do: Map.fetch!(@states_to_ints, to_string(state))
  end

  @spec gen_key(Job.changeset()) :: String.t()
  def gen_key(%{changes: %{unique: unique}} = changeset) do
    %{fields: fields, keys: keys, period: period} = unique

    data =
      fields
      |> Enum.sort()
      |> Enum.map(fn
        :args -> take_keys(changeset, :args, keys)
        :meta -> take_keys(changeset, :meta, keys)
        field -> Changeset.get_field(changeset, field)
      end)

    data =
      if period == :infinity do
        data
      else
        [truncate(period) | data]
      end

    Utils.hash64(data)
  end

  defp take_keys(changeset, field, keys) do
    changeset
    |> Changeset.get_field(field)
    |> Utils.take_keys(keys)
  end

  defp truncate(period) do
    now = DateTime.utc_now()

    now
    |> DateTime.to_unix(:second)
    |> rem(period)
    |> then(&DateTime.add(now, -&1))
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
