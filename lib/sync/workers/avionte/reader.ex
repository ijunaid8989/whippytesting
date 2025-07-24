defmodule Sync.Workers.Avionte.Reader do
  @moduledoc """
  This is a helper module that contains utility functions that would be
  called from the Avionte worker to sync Avionte data into the Sync database.
  """

  alias Sync.Authentication
  alias Sync.Channels
  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Workers.CustomData.Converter

  require Logger

  ##################
  ##    Users     ##
  ##################

  @spec pull_avionte_users(Integration.t()) :: :ok
  def pull_avionte_users(integration) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, users} = Clients.Avionte.list_users(api_key, access_token, tenant)

    Integrations.save_external_users(integration, users)

    :ok
  end

  #####################################
  ##    Branches (Whippy Channels)   ##
  #####################################

  @spec pull_branches(Integration.t()) :: :ok
  def pull_branches(integration) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    case Clients.Avionte.list_branches(api_key, access_token, tenant) do
      {:ok, branches} ->
        Channels.save_external_channels(integration, branches)

      _error ->
        Logger.info("Skipping batch of branches for Avionte integration #{integration.id}")
    end
  end

  ##################
  ##   Contacts   ##
  ##################

  @spec pull_avionte_talents(
          Integration.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def pull_avionte_talents(integration, limit, offset) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, talent_ids} = Clients.Avionte.list_talent_ids(api_key, access_token, tenant, limit: limit, offset: offset)

    case Clients.Avionte.list_talents(api_key, access_token, tenant, talent_ids: talent_ids) do
      {:ok, talents} ->
        talents =
          Enum.reject(talents, & &1.archived)

        Contacts.save_external_contacts(integration, talents)

      _error ->
        Logger.info("Skipping batch of talents: #{inspect(talent_ids)} for Avionte integration #{integration.id}")
    end

    if length(talent_ids) == limit do
      pull_avionte_talents(integration, limit, offset + limit)
    end

    :ok
  end

  @spec pull_avionte_talent_requirements(Integration.t()) :: :ok
  def pull_avionte_talent_requirements(integration) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, talent_requirement} = Clients.Avionte.get_talent_requirement(api_key, access_token, tenant)

    settings = Map.put(integration.settings, "talent_requirement", talent_requirement)
    Integrations.update_integration(integration, %{settings: settings})

    :ok
  end

  def pull_avionte_contacts(integration, limit, offset) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, contact_ids} = Clients.Avionte.list_contact_ids(api_key, access_token, tenant, limit: limit, offset: offset)

    case Clients.Avionte.list_contacts(api_key, access_token, tenant, ids: contact_ids) do
      {:ok, contacts} ->
        contacts =
          Enum.reject(contacts, & &1.archived)

        Contacts.save_external_contacts(integration, contacts)

      _error ->
        Logger.info("Skipping batch of contacts: #{inspect(contact_ids)} for Avionte integration #{integration.id}")
    end

    if length(contact_ids) == limit do
      pull_avionte_contacts(integration, limit, offset + limit)
    end

    :ok
  end

  ########################
  ###  Company Start ###
  ########################
  def pull_avionte_companies(parser_module, integration, custom_object, limit, offset) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, company_ids} = Clients.Avionte.list_company_ids(api_key, access_token, tenant, limit: limit, offset: offset)

    case Clients.Avionte.list_companies(api_key, access_token, tenant, ids: company_ids) do
      {:ok, companies} ->
        companies =
          Enum.reject(companies, & &1.isArchived)

        process_companies_as_custom_data(parser_module, integration, custom_object, companies)

      _error ->
        Logger.info("Skipping batch of companies: #{inspect(company_ids)} for Avionte integration #{integration.id}")
    end

    if length(company_ids) == limit do
      pull_avionte_companies(parser_module, integration, custom_object, limit, offset + limit)
    end

    :ok
  end

  defp process_companies_as_custom_data(parser_module, integration, custom_object, companies) do
    Enum.each(companies, fn company ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             company,
             %{external_resource_id: company.id}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error converting company #{company.id} from Avionte. Skipping company. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error pulling company #{company.id} from Avionte. Skipping company. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  ########################
  ###  Company End ###
  ########################

  ########################
  ###  Placement Start ###
  ########################
  def pull_avionte_placements(parser_module, integration, custom_object, limit, offset) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, placement_ids} = Clients.Avionte.list_placement_ids(api_key, access_token, tenant, limit: limit, offset: offset)

    case Clients.Avionte.list_placements(api_key, access_token, tenant, ids: placement_ids) do
      {:ok, placements} ->
        process_placements_as_custom_data(parser_module, integration, custom_object, placements)

      _error ->
        Logger.info("Skipping batch of placements: #{inspect(placement_ids)} for Avionte integration #{integration.id}")
    end

    if length(placement_ids) == limit do
      pull_avionte_placements(parser_module, integration, custom_object, limit, offset + limit)
    end

    :ok
  end

  defp process_placements_as_custom_data(parser_module, integration, custom_object, placements) do
    Enum.each(placements, fn placement ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             placement,
             %{external_resource_id: placement.id}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error converting placement #{placement.id} from Avionte. Skipping placement. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error pulling placement #{placement.id} from Avionte. Skipping placement. Error: #{inspect(reason)}
          """)
      end
    end)
  end

  ########################
  ###  Placement End ###
  ########################

  ########################
  ###  Job Start ###
  ########################
  def pull_avionte_jobs(parser_module, integration, custom_object, limit, offset) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)
    {:ok, job_ids} = Clients.Avionte.list_job_ids(api_key, access_token, tenant, limit: limit, offset: offset)

    case Clients.Avionte.list_jobs(api_key, access_token, tenant, ids: job_ids) do
      {:ok, jobs} ->
        process_jobs_as_custom_data(parser_module, integration, custom_object, jobs)

      _error ->
        Logger.info("Skipping batch of jobs: #{inspect(job_ids)} for Avionte integration #{integration.id}")
    end

    if length(job_ids) == limit do
      pull_avionte_jobs(parser_module, integration, custom_object, limit, offset + limit)
    end
  end

  defp process_jobs_as_custom_data(parser_module, integration, custom_object, jobs) do
    Enum.each(jobs, fn job ->
      case Converter.convert_external_resource_to_custom_object_record(
             parser_module,
             integration,
             custom_object,
             job,
             %{external_resource_id: job.id}
           ) do
        {:ok, %CustomObjectRecord{}} ->
          :ok

        {:error, %Ecto.Changeset{}} = changeset ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error converting job #{job.id} from Avionte. Skipping job. Error: #{inspect(changeset)}
          """)

        {:error, reason} ->
          Logger.error("""
          [Avionte] [#{integration.id}] Error pulling job #{job.id} from Avionte. Skipping job. Error: #{inspect(reason)}
          """)
      end
    end)
  end
end
