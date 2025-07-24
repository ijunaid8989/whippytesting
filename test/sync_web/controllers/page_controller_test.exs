defmodule SyncWeb.PageControllerTest do
  use SyncWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 302) =~
             "<html><body>You are being <a href=\"/admin/integrations/integration\">redirected</a>.</body></html>"
  end
end
