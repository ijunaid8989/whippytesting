defmodule Sync.Admin.Integrations.User do
  @moduledoc """
  Contains functions to customize the User resource in the admin panel.

  The functions here are customized callbacks from Kaffy.
  For more details, see http://hexdocs.pm/kaffy/readme.html
  """

  def form_fields(_) do
    [
      id: %{type: :id, label: "ID"},
      whippy_organization_id: %{type: :string, label: "Whippy Organization ID"},
      external_organization_id: %{type: :string, label: "External Organization ID"},
      authentication: %{type: :map, label: "Integration Authentication"}
    ]
  end

  def index(_) do
    [
      id: %{type: :id, label: "ID"},
      email: %{type: :string, label: "Email"},
      external_organization_id: %{type: :string, label: "External Organization ID"},
      external_user_id: %{type: :string, label: "External User ID"},
      integration_id: %{type: :id, label: "Integration ID"},
      whippy_organization_id: %{type: :string, label: "Whippy Organization ID"},
      whippy_user_id: %{type: :string, label: "Whippy User ID"},
      inserted_at: %{type: :datetime, label: "Inserted At"},
      updated_at: %{type: :datetime, label: "Updated At"},
      completed_at: %{type: :datetime, label: "Completed At"}
    ]
  end
end
