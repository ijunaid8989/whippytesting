defmodule SyncWeb.Admin.Integrations.ActivityTypeJSON do
  @doc """
  Renders a list of activity types.
  """
  def index(%{activity_types: activity_types}) do
    %{data: for(activity_type <- activity_types, do: data(activity_type))}
  end

  defp data(activity_type) do
    %{
      name: activity_type.name,
      activity_type_id: activity_type.activity_type_id
    }
  end
end
