defmodule SyncWeb.Tempworks.SyncController do
  use SyncWeb, :controller

  def create(conn, %{resource: "users"}) do
    # sync TempWorks users to Sync app

    json(conn, %{message: "Synced users"})
  end
end
