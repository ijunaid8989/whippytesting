defmodule Sync.Admin.Oban.Job do
  @moduledoc """
  Contains functions to customize the Oban Job resource in the admin panel.

  The functions here are customized callbacks from Kaffy.
  For more details, see http://hexdocs.pm/kaffy/readme.html
  """

  def index(_) do
    [
      id: %{type: :id, label: "ID"},
      state: %{type: :string, label: "State"},
      queue: %{type: :string, label: "Queue"},
      worker: %{type: :string, label: "Worker"},
      args: %{type: :map, label: "Args"},
      errors: %{
        type: :string,
        label: "Errors",
        value: fn j -> Jason.encode!(j.errors) end
      },
      attempt: %{type: :integer, label: "Attempt"},
      max_attempts: %{type: :integer, label: "Max Attempts"},
      scheduled_at: %{type: :datetime, label: "Scheduled At"},
      inserted_at: %{type: :datetime, label: "Inserted At"},
      updated_at: %{type: :datetime, label: "Updated At"},
      cancelled_at: %{type: :datetime, label: "Canceled At"},
      discarded_at: %{type: :datetime, label: "Discarded At"}
    ]
  end
end
