defmodule SyncWeb.Tempworks.JobController do
  use SyncWeb, :controller

  alias Sync.Workers.Tempworks

  def create(conn, %{"type" => "pull_employees_from_tempworks", "integration_id" => _integration_id} = job_params) do
    job_params
    |> Tempworks.Employees.new()
    |> Oban.insert()

    json(conn, %{message: "Job created"})
  end

  def create(conn, %{"type" => "push_employees_to_whippy", "integration_id" => _integration_id} = job_params) do
    job_params
    |> Tempworks.Employees.new()
    |> Oban.insert()

    json(conn, %{message: "Job created"})
  end

  def create(conn, %{"type" => "lookup_contacts_in_tempworks", "integration_id" => _integration_id} = job_params) do
    job_params
    |> Tempworks.Employees.new()
    |> Oban.insert()

    json(conn, %{message: "Job created"})
  end
end
