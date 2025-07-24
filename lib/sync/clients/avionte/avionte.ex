defmodule Sync.Clients.Avionte do
  @moduledoc """
  This module serves as the interface to the Avionte Front Office API client.
  """
  alias Sync.Clients.Avionte.Resources.Branch
  alias Sync.Clients.Avionte.Resources.Company
  alias Sync.Clients.Avionte.Resources.Contact
  alias Sync.Clients.Avionte.Resources.ContactActivity
  alias Sync.Clients.Avionte.Resources.Job
  alias Sync.Clients.Avionte.Resources.Placement
  alias Sync.Clients.Avionte.Resources.Talent
  alias Sync.Clients.Avionte.Resources.TalentActivity
  alias Sync.Clients.Avionte.Resources.User

  # TALENT
  defdelegate list_talent_ids(api_key, bearer_token, tenant, opts \\ []), to: Talent
  defdelegate list_talents(api_key, bearer_token, tenant, opts \\ []), to: Talent
  defdelegate create_talent(api_key, bearer_token, tenant, opts), to: Talent
  defdelegate get_talent_requirement(api_key, bearer_token, tenant), to: Talent

  # TALENT ACTIVITIES
  defdelegate create_talent_activity(api_key, bearer_token, tenant, opts), to: TalentActivity
  defdelegate list_talent_activity_types(api_key, bearer_token, tenant), to: TalentActivity

  # USERS
  defdelegate list_user_ids(api_key, bearer_token, tenant, opts \\ []), to: User
  defdelegate list_users(api_key, bearer_token, tenant), to: User

  # BRANCHES
  defdelegate list_branches(api_key, bearer_token, tenant), to: Branch

  # COMPANIES
  defdelegate list_company_ids(api_key, bearer_token, tenant, opts \\ []), to: Company
  defdelegate list_companies(api_key, bearer_token, tenant, opts \\ []), to: Company

  # CONTACTS
  defdelegate list_contact_ids(api_key, bearer_token, tenant, opts \\ []), to: Contact
  defdelegate list_contacts(api_key, bearer_token, tenant, opts \\ []), to: Contact

  # CONTACT ACTIVITIES
  defdelegate create_contact_activity(api_key, bearer_token, tenant, opts), to: ContactActivity

  defdelegate list_contact_activity_types(api_key, bearer_token, tenant), to: ContactActivity

  # JOBS
  defdelegate list_job_ids(api_key, bearer_token, tenant, opts \\ []), to: Job
  defdelegate list_jobs(api_key, bearer_token, tenant, opts \\ []), to: Job

  # PLACEMENTS
  defdelegate list_placement_ids(api_key, bearer_token, tenant, opts \\ []), to: Placement
  defdelegate list_placements(api_key, bearer_token, tenant, opts \\ []), to: Placement
end
