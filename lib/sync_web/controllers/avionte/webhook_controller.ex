defmodule SyncWeb.Avionte.WebhookController do
  use SyncWeb, :controller

  alias Plug.Conn
  alias Sync.Webhooks.Avionte

  def webhook(conn, data) do
    Avionte.process_event(data)
    Conn.send_resp(conn, 200, [])
  end
end
