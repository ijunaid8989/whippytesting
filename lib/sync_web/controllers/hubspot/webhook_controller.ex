defmodule SyncWeb.Hubspot.WebhookController do
  use SyncWeb, :controller

  alias Plug.Conn
  alias Sync.Actions.Hubspot, as: HubspotAction
  alias Sync.Webhooks.Hubspot, as: HubspotWebhook

  plug :validate_hubspot_timestamp when action in [:webhook, :get_channels, :send_sms]
  plug :validate_hubspot_signature when action in [:webhook, :get_channels, :send_sms]
  plug :validate_whippy_signature when action == :whippy

  def webhook(conn, data) do
    HubspotWebhook.process_events(data["_json"])
    Conn.send_resp(conn, 200, [])
  end

  def get_channels(conn, data) do
    channels = HubspotAction.get_channels(data)
    json(conn, %{options: Enum.map(channels, &%{value: &1.id, label: &1.name, description: &1.description})})
  end

  def send_sms(conn, data) do
    json(conn, %{
      "outputFields" => %{
        "hs_execution_state" =>
          case HubspotAction.send_sms(data) do
            :ok -> "SUCCESS"
            :error -> "FAIL_CONTINUE"
          end
      }
    })
  end

  def whippy(conn, data) do
    activity = data["data"]

    hubspot_activity?(activity, data["event"] == "call.analyzed") &&
      HubspotAction.push_activities(
        conn.query_params["integration_id"],
        [
          %{
            whippy_activity: activity
          }
        ]
      )

    send_resp(conn, 200, "OK")
  end

  defp hubspot_activity?(%{"type" => "note"}, false) do
    true
  end

  defp hubspot_activity?(%{"type" => type} = activity, false) when type in ["email", "sms", "mms", "whatsapp"] do
    activity["delivery_status"] in ["delivered", "delivery_unconfirmed"]
  end

  defp hubspot_activity?(%{"type" => "call"} = _activity, call_analyzed) do
    call_analyzed
  end

  defp hubspot_activity?(_activity, _call_analyzed) do
    false
  end

  # Validate hubspot signature v3
  # More info https://developers.hubspot.com/docs/api/webhooks/validating-requests
  defp validate_hubspot_signature(conn, _opts) do
    [signature] = Conn.get_req_header(conn, "x-hubspot-signature-v3")
    [timestamp] = Conn.get_req_header(conn, "x-hubspot-request-timestamp")
    request_uri = System.get_env("BASE_URL") <> "/" <> Enum.join(conn.path_info, "/")
    client_secret = System.get_env("HUBSPOT_CLIENT_SECRET")

    is_valid =
      :hmac
      |> :crypto.mac(:sha256, client_secret, "POST#{request_uri}#{conn.assigns.raw_body}#{timestamp}")
      |> Base.encode64()
      |> Kernel.==(signature)

    if is_valid do
      conn
    else
      conn |> send_resp(401, "Invalid signature") |> halt()
    end
  end

  # Make sure timestamp is not older than 5 seconds
  defp validate_hubspot_timestamp(conn, _opts) do
    [timestamp] = Conn.get_req_header(conn, "x-hubspot-request-timestamp")
    {timestamp, _} = Integer.parse(timestamp)

    if :os.system_time(:millisecond) - 5 * 1000 > timestamp do
      conn |> put_status(401) |> halt()
    else
      conn
    end
  end

  defp validate_whippy_signature(conn, _opts) do
    conn
    # [signature_header] = Conn.get_req_header(conn, "x-whippy-signature")
    # [timestamp_part, signature_part] = String.split(signature_header, ",")
    # [_, timestamp] = String.split(timestamp_part, "=")
    # [_, signature] = String.split(signature_part, "=")

    # body = conn.body_params
    # integration_id = conn.query_params["integration_id"]
    # %{authentication: %{"whippy_api_key" => whippy_api_key}} = Integrations.get_integration!(integration_id)
    # payload = "#{timestamp}.#{Jason.encode!(body)}"

    # IO.inspect(payload, label: "PAYLOAD")

    # generated_signature =
    #   :hmac
    #   |> :crypto.mac(:sha256, whippy_api_key, payload)
    #   |> Base.encode64(padding: false)

    # if generated_signature == signature do
    #   conn
    # else
    #   conn |> send_resp(401, "Invalid signature") |> halt()
    # end
  end
end
