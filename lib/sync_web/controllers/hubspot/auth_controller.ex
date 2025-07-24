defmodule SyncWeb.Hubspot.AuthController do
  use SyncWeb, :controller

  def new(conn, %{"data" => data}) when is_binary(data) do
    %{"organization_id" => organization_id, "api_key" => api_key} =
      data
      |> Base.decode64!()
      |> Jason.decode!()

    case Sync.Authentication.Hubspot.get_user_authorization_url(organization_id, api_key) do
      {:ok, url} ->
        conn
        |> redirect(external: url)
        |> halt()

      {:error, reason} ->
        json(conn, %{error: reason})
    end
  end

  def new(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid parameters"}))
  end

  def callback(conn, %{"code" => code, "state" => data}) do
    %{"organization_id" => organization_id, "api_key" => api_key} =
      data
      |> Base.decode64!()
      |> Jason.decode!()

    case Sync.Authentication.Hubspot.exchange_code_for_token(organization_id, api_key, code) do
      {:ok, _} ->
        redirect(conn, external: Application.fetch_env!(:sync, :whippy_dashboard) <> "/integrations")

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: reason}))
    end
  end
end
