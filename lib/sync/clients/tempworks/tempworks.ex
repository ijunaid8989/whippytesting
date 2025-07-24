defmodule Sync.Clients.Tempworks do
  @moduledoc """
    This methods serve as a wrapper to make HTTP requests to the tempworks client.
  """
  alias Sync.Clients.Tempworks.Resources.Assignment
  alias Sync.Clients.Tempworks.Resources.Branch
  alias Sync.Clients.Tempworks.Resources.Customers
  alias Sync.Clients.Tempworks.Resources.DataList
  alias Sync.Clients.Tempworks.Resources.Employee
  alias Sync.Clients.Tempworks.Resources.Jobs
  alias Sync.Clients.Tempworks.Resources.Webhook

  defdelegate list_assignments(access_token, opts \\ []), to: Assignment
  defdelegate get_assignment_custom_data(access_token, assignment_id), to: Assignment
  defdelegate list_assignment_columns(access_token), to: Assignment
  defdelegate list_assignments_advance_details(access_token, opts \\ []), to: Assignment

  defdelegate list_branches(access_token, opts \\ []), to: Branch
  defdelegate list_employees(access_token, opts \\ []), to: Employee
  defdelegate create_employee(access_token, body), to: Employee

  defdelegate list_contacts(access_token, opts \\ []), to: Employee

  defdelegate create_employee_message(access_token, employee_id, action_id, message_body),
    to: Employee

  defdelegate create_contact_message(access_token, contact_id, action_id, message_body),
    to: Employee

  defdelegate list_message_actions(access_token, opts \\ []), to: DataList

  defdelegate get_employee(access_token, id), to: Employee
  defdelegate get_employee_custom_data(access_token, id), to: Employee

  defdelegate get_contact(access_token, id), to: Employee

  @spec get_contact_search_by_id(binary(), any()) :: any()
  defdelegate get_contact_search_by_id(access_token, id), to: Employee

  defdelegate get_tempwork_contact_custom_data(access_token, id), to: Employee

  defdelegate list_employee_assignments(access_token, id, opts \\ []), to: Employee
  defdelegate get_employee_eeo(access_token, id), to: Employee
  defdelegate get_employee_universal_phone(access_token, phone), to: Employee
  defdelegate get_employee_universal_email(access_token, email), to: Employee
  defdelegate get_employee_status(access_token, employee_id), to: Employee

  defdelegate list_employee_columns(access_token), to: Employee
  defdelegate list_employees_advance_details(access_token, opts \\ []), to: Employee
  defdelegate list_todays_employees(access_token), to: Employee

  defdelegate get_contact_contact_methods(access_token, id), to: Employee

  defdelegate list_subscriptions(access_token), to: Webhook
  defdelegate subscribe_topic(access_token, body), to: Webhook

  defdelegate list_job_orders(access_token, opts \\ []), to: Jobs
  defdelegate get_job_orders_custom_data(access_token, order_id), to: Jobs

  defdelegate list_customers(access_token, opts \\ []), to: Customers
  defdelegate get_customers_custom_data(access_token, customer_id), to: Customers
end
