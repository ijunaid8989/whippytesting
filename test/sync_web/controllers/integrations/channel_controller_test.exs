defmodule SyncWeb.Integrations.ChannelControllerTest do
  @moduledoc false

  use SyncWeb.ConnCase, async: false

  import Mock
  import Sync.Factory

  setup do
    integration = insert(:integration)

    channel =
      insert(:channel,
        integration: integration,
        external_channel_id: "branch",
        whippy_channel_id: nil,
        whippy_organization_id: integration.whippy_organization_id
      )

    %{channel: channel, integration: integration}
  end

  describe "update/2" do
    test "updates the Whippy channel id for the given external channel id and integration id", %{
      conn: conn,
      channel: channel,
      integration: integration
    } do
      params = %{
        whippy_channel_id: Ecto.UUID.generate()
      }

      with_mock(Sync.Workers.Whippy.Reader, [], whippy_reader_mocks()) do
        conn =
          conn
          |> put_req_header("authorization", "Basic " <> Base.encode64("username:password"))
          |> put(
            ~p"/api/v1/integrations/#{integration.id}/channels/external/#{channel.external_channel_id}",
            params
          )

        assert json_response(conn, 200) == %{
                 "message" =>
                   "Synced branch #{channel.external_channel_id} to Whippy channel #{params.whippy_channel_id} for integration #{integration.id}",
                 "channel" => %{
                   "external_channel_id" => channel.external_channel_id,
                   "whippy_channel_id" => params.whippy_channel_id,
                   "integration_id" => integration.id,
                   "id" => channel.id,
                   "external_organization_id" => channel.external_organization_id,
                   "whippy_organization_id" => channel.whippy_organization_id,
                   "timezone" => "America/Chicago"
                 }
               }
      end
    end

    test "when a channel is already associated with another Whippy channel and no record with NULL Whippy channel ID exists, return error",
         %{
           conn: conn,
           channel: channel,
           integration: integration
         } do
      with_mock(Sync.Workers.Whippy.Reader, [], whippy_reader_mocks()) do
        whippy_channel_id = Ecto.UUID.generate()

        params = %{
          whippy_channel_id: whippy_channel_id
        }

        first_conn =
          conn
          |> put_req_header("authorization", "Basic " <> Base.encode64("username:password"))
          |> put(
            ~p"/api/v1/integrations/#{integration.id}/channels/external/#{channel.external_channel_id}",
            params
          )

        assert json_response(first_conn, 200) == %{
                 "message" =>
                   "Synced branch #{channel.external_channel_id} to Whippy channel #{params.whippy_channel_id} for integration #{integration.id}",
                 "channel" => %{
                   "external_channel_id" => channel.external_channel_id,
                   "whippy_channel_id" => whippy_channel_id,
                   "integration_id" => integration.id,
                   "id" => channel.id,
                   "external_organization_id" => channel.external_organization_id,
                   "whippy_organization_id" => channel.whippy_organization_id,
                   "timezone" => "America/Chicago"
                 }
               }

        new_whippy_channel_id = Ecto.UUID.generate()

        params = %{
          whippy_channel_id: new_whippy_channel_id
        }

        second_conn =
          conn
          |> put_req_header("authorization", "Basic " <> Base.encode64("username:password"))
          |> put(
            ~p"/api/v1/integrations/#{integration.id}/channels/external/#{channel.external_channel_id}",
            params
          )

        assert json_response(second_conn, 404) == %{
                 "errors" => [
                   %{
                     "description" => "Available Channel branch not found for integration #{channel.integration_id}"
                   }
                 ]
               }
      end
    end

    test "returns an error message when the Whippy channel id could not be associated to the external channel id", %{
      conn: conn,
      channel: channel,
      integration: integration
    } do
      params = %{
        whippy_channel_id: nil
      }

      conn =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("username:password"))
        |> put(
          ~p"/api/v1/integrations/#{integration.id}/channels/external/#{channel.external_channel_id}",
          params
        )

      assert json_response(conn, 422) == %{
               "errors" => [
                 %{"description" => "Invalid params - integration_id or whippy_channel_id is not a valid UUID"}
               ]
             }
    end

    test "returns an error message when the channel is not found for the given integration id and external channel id", %{
      conn: conn,
      integration: integration
    } do
      params = %{
        whippy_channel_id: Ecto.UUID.generate()
      }

      with_mock(Sync.Workers.Whippy.Reader, [], whippy_reader_mocks()) do
        conn =
          conn
          |> put_req_header("authorization", "Basic " <> Base.encode64("username:password"))
          |> put(~p"/api/v1/integrations/#{integration.id}/channels/external/non-existent-branch", params)

        assert json_response(conn, 404) == %{
                 "errors" => [
                   %{"description" => "Available Channel non-existent-branch not found for integration #{integration.id}"}
                 ]
               }
      end
    end
  end

  defp whippy_reader_mocks do
    [
      get_channel: fn _integration, _whippy_channel_id ->
        %Sync.Clients.Whippy.Model.Channel{
          address: "Test address",
          automatic_response_closed: nil,
          automatic_response_open: nil,
          id: "1c3ed961-c204-4bbd-8bd4-2f6b994cb704",
          name: "Twilio",
          opening_hours: [
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Monday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Tuesday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Wednesday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Thursday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Friday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Saturday"
            },
            %{
              "closes_at" => "23:30",
              "opens_at" => "00:00",
              "state" => "open",
              "weekday" => "Sunday"
            }
          ],
          phone: "+12183925232",
          send_automatic_response_when: "never",
          timezone: "America/Chicago",
          created_at: nil,
          updated_at: nil
        }
      end
    ]
  end
end
