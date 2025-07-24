defmodule Sync.Clients.Aqore do
  @moduledoc """
  Aqore API client
  """

  alias Sync.Clients.Aqore.Resources.AqoreContacts
  alias Sync.Clients.Aqore.Resources.AqoreOrganizationData
  alias Sync.Clients.Aqore.Resources.Assignments
  alias Sync.Clients.Aqore.Resources.Candidates
  alias Sync.Clients.Aqore.Resources.Comments
  alias Sync.Clients.Aqore.Resources.JobCandidates
  alias Sync.Clients.Aqore.Resources.Jobs
  alias Sync.Clients.Aqore.Resources.Users

  # Candidates
  defdelegate list_candidates(details, limit, offset, sync),
    to: Candidates

  defdelegate create_candidate(candidate, details),
    to: Candidates

  defdelegate search_candidate_by_phone(phone, details),
    to: Candidates

  # Contacts
  defdelegate list_aqore_contacts(details, limit, offset, sync),
    to: AqoreContacts

  # Job Candidates
  defdelegate list_job_candidates(details, limit, offset, sync),
    to: JobCandidates

  # Jobs
  defdelegate list_jobs(details, limit, offset, sync),
    to: Jobs

  # Assignments
  defdelegate list_assignments(details, limit, offset, sync),
    to: Assignments

  # Comments
  defdelegate create_comment(details, payload),
    to: Comments

  # Users
  defdelegate list_users(details, limit, offset, sync),
    to: Users

  # Organization Data
  defdelegate list_organization_data(details, limit, offset, sync),
    to: AqoreOrganizationData
end
