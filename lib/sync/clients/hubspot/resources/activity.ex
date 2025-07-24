defmodule Sync.Clients.Hubspot.Resources.Activity do
  @moduledoc false
  alias Sync.Clients.Hubspot.Parser

  @api_paths %{
    sms: "/crm/v3/objects/communications/batch/create",
    whatsapp: "/crm/v3/objects/communications/batch/create",
    email: "/crm/v3/objects/emails/batch/create",
    call: "/crm/v3/objects/calls/batch/create",
    note: "/crm/v3/objects/notes/batch/create"
  }

  def push_activities(client, activities) do
    Enum.map([:sms, :call, :email, :whatsapp, :note], fn type ->
      type_activities =
        Enum.filter(activities, fn activity -> Map.get(activity.whippy_activity, "type") == Atom.to_string(type) end)

      if length(type_activities) > 0 do
        parsed_activities = Enum.map(activities, &Parser.parse(type, &1))

        client.(
          :post,
          Map.get(@api_paths, type),
          %{
            inputs: parsed_activities
          },
          false
        )
      end
    end)
  end
end
