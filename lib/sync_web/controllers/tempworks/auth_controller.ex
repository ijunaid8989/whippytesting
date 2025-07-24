defmodule SyncWeb.Tempworks.AuthController do
  use SyncWeb, :controller

  alias Sync.Integrations
  alias Sync.Integrations.Integration

  @final_redirect_url "https://app.whippy.co/integrations/69f33c52-8804-4c7c-abf6-30f42ee24391"

  def new(conn, %{"integration_id" => integration_id, "user_id" => whippy_user_id})
      when is_binary(integration_id) and is_binary(whippy_user_id) do
    integration = %Integration{} = Integrations.get_integration!(integration_id)

    case Sync.Authentication.Tempworks.get_user_authorization_url(integration, whippy_user_id) do
      {:ok, url} ->
        conn
        |> redirect(external: url)
        |> halt()

      {:error, reason} ->
        json(conn, %{error: reason})
    end
  rescue
    _ ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "Integration not found"}))
  end

  def new(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid parameters"}))
  end

  def callback(conn, %{"code" => code, "state" => state_user_id}) do
    case Sync.Authentication.Tempworks.exchange_code_for_token(state_user_id, code) do
      {:ok, _updated_integration} ->
        conn
        |> redirect(external: @final_redirect_url)
        |> halt()

      {:error, reason} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{error: reason}))
    end
  end
end
