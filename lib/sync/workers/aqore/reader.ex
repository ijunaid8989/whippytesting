defmodule Sync.Workers.Aqore.Reader do
  @moduledoc false
  alias Sync.Authentication
  alias Sync.Clients
  alias Sync.Clients.Aqore.Parser
  alias Sync.Contacts
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Integrations
  alias Sync.Workers.CustomData.Converter

  require Logger

  ################
  ## Candidates ##
  ################

  def pull_aqore_candidates(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    Logger.info("Pulling candidates from Aqore", metadata)

    case Clients.Aqore.list_candidates(details, limit, offset, sync) do
      {:ok, candidates} ->
        Contacts.save_external_contacts(integration, candidates)

        if length(candidates) < limit or sync == :daily_sync do
          :ok
        else
          pull_aqore_candidates(integration, limit, offset + limit, sync)
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling candidates from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, error} ->
        Logger.error("Error while fetching candidates", [error: inspect(error)] ++ metadata)
        # skip batch and move to the next one only if not daily sync
        if sync == :daily_sync do
          :ok
        else
          pull_aqore_candidates(integration, limit, offset + limit, sync)
        end
    end
  end

  def lookup_candidates_in_aqore(integration, limit) do
    contacts = Contacts.list_integration_contacts_missing_from_external_integration_for_lookup(integration, limit)

    Enum.each(contacts, fn contact ->
      contact.whippy_contact["phone"] && get_and_update_candidate(integration, contact)
    end)

    Contacts.update_contacts_as_looked_up(integration, contacts)

    if Enum.count(contacts) < limit do
      :ok
    else
      lookup_candidates_in_aqore(integration, limit)
    end
  end

  ####################
  ## Job Candidates ##
  ####################

  def pull_job_candidates(parser_module, integration, custom_object, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    case Clients.Aqore.list_job_candidates(details, limit, offset, sync) do
      {:ok, %{job_candidates: job_candidates}} ->
        candidates_ids = Enum.map(job_candidates, & &1.candidateId)

        # Find contacts where external_contact_id is in candidates_ids and integration_id = integration_id
        external_candidates_ids =
          Contacts.list_integration_synced_external_contact_ids_by_external_contact_ids_list(integration, candidates_ids)

        selected_candidates =
          Enum.filter(job_candidates, &(&1.candidateId in external_candidates_ids))

        Logger.info("Found candidates for job in the integration.", [count: Enum.count(selected_candidates)] ++ metadata)

        save_job_candidates(parser_module, selected_candidates, integration, custom_object)

        if Enum.count(job_candidates) < limit or sync == :daily_sync do
          :ok
        else
          pull_job_candidates(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling job candidates from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, reason} ->
        Logger.error("Error pulling job candidates from Aqore. Skipping batch.", [error: inspect(reason)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          # skip batch and move to the next one
          pull_job_candidates(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end
    end
  end

  defp save_job_candidates(parser_module, selected_candidates, integration, custom_object) do
    Enum.each(selected_candidates, fn candidate ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             candidate
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("Error converting job candidate from Aqore. Skipping job candidate.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: candidate.id,
            error: inspect(changeset)
          )

        {:error, reason} ->
          Logger.error("Error pulling job candidate from Aqore. Skipping job candidate.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: candidate.id,
            error: inspect(reason)
          )
      end
    end)
  end

  ########################
  ## Job Candidates END ##
  ########################

  ################
  ## Jobs Start ##
  ################

  def pull_jobs(parser_module, integration, custom_object, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    case Clients.Aqore.list_jobs(details, limit, offset, sync) do
      {:ok, %{jobs: jobs}} ->
        save_jobs(parser_module, jobs, integration, custom_object)

        if Enum.count(jobs) < limit or sync == :daily_sync do
          :ok
        else
          pull_jobs(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling jobs from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, reason} ->
        Logger.error("Error pulling jobs from Aqore. Skipping batch.", [error: inspect(reason)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          # skip batch and move to the next one
          pull_jobs(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end
    end
  end

  defp save_jobs(parser_module, jobs, integration, custom_object) do
    Enum.each(jobs, fn job ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             job
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("Error converting job from Aqore. Skipping job.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: job.id,
            error: inspect(changeset)
          )

        {:error, reason} ->
          Logger.error("Error pulling job from Aqore. Skipping job.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: job.id,
            error: inspect(reason)
          )
      end
    end)
  end

  ##############
  ## Jobs END ##
  ##############

  #######################
  ## Assignments Start ##
  #######################

  def pull_assignments(parser_module, integration, custom_object, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    case Clients.Aqore.list_assignments(details, limit, offset, sync) do
      {:ok, %{assignments: assignments}} ->
        save_assignments(parser_module, assignments, integration, custom_object)

        if Enum.count(assignments) < limit or sync == :daily_sync do
          :ok
        else
          pull_assignments(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling assignments from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, reason} ->
        Logger.error("Error pulling assignments from Aqore. Skipping batch.", [error: inspect(reason)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          # skip batch and move to the next one
          pull_assignments(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end
    end
  end

  defp save_assignments(parser_module, assignments, integration, custom_object) do
    Enum.each(assignments, fn assignment ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             assignment
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("Error converting assignment from Aqore. Skipping assignment.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: assignment.id,
            error: inspect(changeset)
          )

        {:error, reason} ->
          Logger.error("Error pulling assignment from Aqore. Skipping assignment.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: assignment.id,
            error: inspect(reason)
          )
      end
    end)
  end

  #####################
  ## Assignments END ##
  #####################

  ###########
  ## Users ##
  ###########

  def pull_aqore_users(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    case Clients.Aqore.list_users(details, limit, offset, sync) do
      {:ok, users} ->
        Integrations.save_external_users(integration, users)

        if length(users) < limit or sync == :daily_sync do
          :ok
        else
          pull_aqore_users(integration, limit, offset + limit, sync)
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling users from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, error} ->
        Logger.error("Error while fetching users", [error: inspect(error)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          # skip batch and move to the next one
          pull_aqore_users(integration, limit, offset + limit, sync)
        end
    end
  end

  ###########
  ## Contacts ##
  ###########
  def pull_aqore_contacts(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    Logger.info("Pulling contacts from Aqore", metadata)

    case Clients.Aqore.list_aqore_contacts(details, limit, offset, sync) do
      {:ok, contacts} ->
        Contacts.save_external_contacts(integration, contacts)

        if length(contacts) < limit or sync == :daily_sync do
          :ok
        else
          pull_aqore_contacts(integration, limit, offset + limit, sync)
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling contacts from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, error} ->
        Logger.error("Error while fetching contacts", [error: inspect(error)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          pull_aqore_contacts(integration, limit, offset + limit, sync)
        end
    end
  end

  ###########
  ## Others ##
  ###########
  def get_and_update_candidate(integration, contact) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    opts = %{
      office_id: integration.settings["office_id"],
      office_name: integration.settings["office_name"]
    }

    contact
    |> Clients.Aqore.Parser.convert_contact_to_candidate(opts)
    |> then(fn
      {:error, error_message} ->
        {:error, error_message}

      candidate ->
        case Clients.Aqore.search_candidate_by_phone(candidate.mobile, details) do
          {:ok, []} ->
            {:error, "[Aqore] no contact details found in aqore for this phone #{candidate.mobile}"}

          {:error, error} ->
            Logger.error("Error getting candidate by phone",
              integration_id: integration.id,
              integration_client: integration.client,
              phone: candidate.mobile,
              error: inspect(error)
            )

            {:error, error}

          {:ok, existing_candidate_list} ->
            existing_candidate = List.first(existing_candidate_list)

            sync_contact_update_params =
              %{}
              |> Map.put(:name, "#{existing_candidate.name}")
              |> Map.put(:email, existing_candidate.email)
              |> Map.put(:address, existing_candidate.address)
              |> Map.put(:birth_date, existing_candidate.birth_date)

            Contacts.update_contact_synced_in_external_integration(
              integration,
              contact,
              existing_candidate.external_contact.id,
              existing_candidate.external_contact,
              "candidate",
              sync_contact_update_params
            )
        end
    end)
  end

  def get_organization_custom_details(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    references = [%{key: "organization_id", type: "organization_data"}]

    case Clients.Aqore.list_organization_data(details, limit, offset, sync) do
      {:ok, %{organization_data: []}} ->
        Logger.info("Organization data not found for custom object.",
          integration_id: integration.id,
          integration_client: integration.client
        )

        nil

      {:ok, %{organization_data: [organization_data | _organization_datas]}} ->
        Parser.process_data_to_properties(organization_data, references, [])

      {:error, reason} ->
        Logger.error("Error getting organization data for custom object.",
          integration_id: integration.id,
          integration_client: integration.client,
          error: inspect(reason)
        )

        nil
    end
  end

  def get_job_candidates_custom_details(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)
    references = [%{key: "candidate_id", type: "candidate"}, %{key: "job_id", type: "job"}]

    whippy_associations = [
      %{
        target_whippy_resource: "contact",
        target_property_key: "external_id",
        target_property_key_prefix: nil,
        source_property_key: "candidate_id",
        type: "one_to_one"
      }
    ]

    case Clients.Aqore.list_job_candidates(details, limit, offset, sync) do
      {:ok, %{job_candidates: []}} ->
        Logger.info("Job candidate data not found for custom object.",
          integration_id: integration.id,
          integration_client: integration.client
        )

        nil

      {:ok, %{job_candidates: [job_candidate | _job_candidates]}} ->
        Parser.process_data_to_properties(job_candidate, references, whippy_associations)

      {:error, reason} ->
        Logger.error("Error getting job candidates data for custom object.",
          integration_id: integration.id,
          integration_client: integration.client,
          error: inspect(reason)
        )

        nil
    end
  end

  def get_job_custom_details(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    references = [%{key: "job_id", type: "job_candidate"}, %{key: "organization_id", type: "organization_data"}]

    case Clients.Aqore.list_jobs(details, limit, offset, sync) do
      {:ok, %{jobs: []}} ->
        Logger.info("Jobs data not found for custom object.",
          integration_id: integration.id,
          integration_client: integration.client
        )

        nil

      {:ok, %{jobs: [job | _jobs]}} ->
        Parser.process_data_to_properties(job, references, [])

      {:error, reason} ->
        Logger.error("Error getting job data for custom object.",
          integration_id: integration.id,
          integration_client: integration.client,
          error: inspect(reason)
        )

        nil
    end
  end

  def get_assignment_custom_details(integration, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    references = [
      %{key: "candidate_id", type: "candidate"},
      %{key: "job_id", type: "job"},
      %{key: "organization_id", type: "organization_data"}
    ]

    whippy_associations = [
      %{
        target_whippy_resource: "contact",
        target_property_key: "external_id",
        target_property_key_prefix: nil,
        source_property_key: "candidate_id",
        type: "one_to_one"
      }
    ]

    case Clients.Aqore.list_assignments(details, limit, offset, sync) do
      {:ok, %{assignments: []}} ->
        Logger.info("Assignment data not found for custom object.",
          integration_id: integration.id,
          integration_client: integration.client
        )

        nil

      {:ok, %{assignments: [assignment | _assignments]}} ->
        Parser.process_data_to_properties(assignment, references, whippy_associations)

      {:error, reason} ->
        Logger.error("Error getting assignment data for custom object.",
          integration_id: integration.id,
          integration_client: integration.client,
          error: inspect(reason)
        )

        nil
    end
  end

  ####################
  ## Organization Data ##
  ####################

  def pull_organization_data(parser_module, integration, custom_object, limit, offset, sync) do
    {:ok, details} = Authentication.Aqore.get_integration_details(integration)

    metadata = [
      integration_id: integration.id,
      integration_client: integration.client,
      sync: sync,
      offset: offset,
      limit: limit
    ]

    case Clients.Aqore.list_organization_data(details, limit, offset, sync) do
      {:ok, %{organization_data: organization_data}} ->
        Logger.info("Found organization data in the integration.",
          integration_id: integration.id,
          integration_client: integration.client,
          count: Enum.count(organization_data)
        )

        save_organization_data(parser_module, organization_data, integration, custom_object)

        if Enum.count(organization_data) < limit or sync == :daily_sync do
          :ok
        else
          pull_organization_data(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end

      {:error, {"message", message}} ->
        Logger.warning("Warning pulling organization data from Aqore", [error: inspect(message)] ++ metadata)
        :ok

      {:error, reason} ->
        Logger.error("Error pulling organization data from Aqore. Skipping batch.", [error: inspect(reason)] ++ metadata)

        if sync == :daily_sync do
          :ok
        else
          # skip batch and move to the next one
          pull_organization_data(
            parser_module,
            integration,
            custom_object,
            limit,
            offset + limit,
            sync
          )
        end
    end
  end

  defp save_organization_data(parser_module, organization_data, integration, custom_object) do
    Enum.each(organization_data, fn data ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             data
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("Error converting organization data from Aqore. Skipping organization_data.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: data.id,
            error: inspect(changeset)
          )

        {:error, reason} ->
          Logger.error("Error pulling organization data from Aqore. Skipping organization_data.",
            integration_id: integration.id,
            integration_client: integration.client,
            id: data.id,
            error: inspect(reason)
          )
      end
    end)
  end

  ########################
  ## Organization Data END ##
  ########################
end
