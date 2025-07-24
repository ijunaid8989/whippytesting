defmodule Oban.Pro.Handler do
  @moduledoc false

  @doc """
  Attach handler hooks.
  """
  @callback on_start() :: any()

  @doc """
  Teardown handler hooks.
  """
  @callback on_stop() :: any()
end
