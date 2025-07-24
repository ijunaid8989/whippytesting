defmodule SyncWeb.Plug.CacheBodyReader do
  @moduledoc """
  Capture request's raw body and keep it in assigns with :raw_body key
  for validation purposes later on.

  https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
