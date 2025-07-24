defmodule SyncWeb.Tempworks.WebhookController do
  use SyncWeb, :controller

  alias Plug.Conn
  alias Sync.Webhooks.Tempworks

  def webhook(conn, data) do
    whippy_organization_id = conn |> get_req_header("whippy_organization_id") |> List.first()
    Tempworks.process_event(data, whippy_organization_id)
    Conn.send_resp(conn, 200, [])
  end
end
