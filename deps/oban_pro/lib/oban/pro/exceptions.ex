defmodule Oban.Pro.WorkflowError do
  @moduledoc false

  defexception [:message, :reason]

  @impl Exception
  def exception(reason) do
    message = "upstream job was #{reason}, workflow can't complete"

    %__MODULE__{message: message, reason: reason}
  end
end
