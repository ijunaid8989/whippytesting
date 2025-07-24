defmodule Sync.ActivitiesTest do
  use Sync.DataCase

  import Sync.Factory

  alias Sync.Activities
  alias Sync.Activities.Activity

  describe "activities" do
    test "list_whippy_contact_messages_missing_from_external_integration/2 lists whippy messages" do
      integration = insert(:integration)
      whippy_contact_id = Ecto.UUID.generate()
      whippy_activity_id = Ecto.UUID.generate()

      insert(:activity,
        integration: integration,
        external_organization_id: integration.external_organization_id,
        external_activity_id: nil,
        whippy_activity_id: whippy_activity_id,
        whippy_contact_id: whippy_contact_id,
        whippy_activity_id: whippy_activity_id
      )

      assert [%Activity{}] =
               Activities.list_whippy_contact_messages_missing_from_external_integration(integration, whippy_contact_id)
    end
  end

  describe "list_whippy_messages_with_the_gap_of_inactivity/5" do
    test "list_whippy_messages_with_the_gap_of_inactivity/5 get message which are only 15 minutes older" do
      integration = insert(:integration)
      now = DateTime.utc_now()
      fifteen_minutes_ago = DateTime.add(now, -16 * 60, :second)
      conversation1 = Ecto.UUID.generate()
      conversation2 = Ecto.UUID.generate()

      _activity1 =
        insert_activity(%{
          whippy_activity_inserted_at: fifteen_minutes_ago,
          whippy_conversation_id: conversation1,
          integration: integration,
          external_organization_id: integration.external_organization_id,
          external_contact_id: "1"
        })

      _activity2 =
        insert_activity(%{
          whippy_activity_inserted_at: now,
          whippy_conversation_id: conversation2,
          integration: integration,
          external_organization_id: integration.external_organization_id,
          external_contact_id: "2"
        })

      assert [%Activity{} = activity] =
               Activities.list_whippy_messages_with_the_gap_of_inactivity(integration, 10, 0)

      assert activity.whippy_conversation_id == conversation1
    end

    test "list_whippy_messages_with_the_gap_of_inactivity/5 should return null if there is an activity" do
      integration = insert(:integration)

      now = DateTime.utc_now()
      five_minutes_ago = DateTime.add(now, -5 * 60, :second)
      conversation1 = Ecto.UUID.generate()
      conversation2 = Ecto.UUID.generate()

      _activity1 =
        insert_activity(%{
          whippy_activity_inserted_at: now,
          whippy_conversation_id: conversation1,
          integration: integration,
          external_organization_id: integration.external_organization_id
        })

      _activity2 =
        insert_activity(%{
          whippy_activity_inserted_at: five_minutes_ago,
          whippy_conversation_id: conversation2,
          integration: integration,
          external_organization_id: integration.external_organization_id
        })

      assert [] =
               Activities.list_whippy_messages_with_the_gap_of_inactivity(integration, 10, 0)
    end
  end

  defp insert_activity(attrs) do
    # Default values for the activity
    integration = insert(:integration)

    defaults = %{
      integration: integration,
      external_organization_id: integration.external_organization_id,
      external_activity_id: nil,
      whippy_activity_id: Ecto.UUID.generate(),
      whippy_contact_id: Ecto.UUID.generate(),
      whippy_conversation_id: Ecto.UUID.generate(),
      whippy_activity: %{},
      whippy_activity_inserted_at: DateTime.utc_now()
    }

    # Merge the provided `attrs` with the default values
    values = Map.merge(defaults, attrs)

    # Insert the activity using the merged values
    insert(:activity, values)
  end
end
