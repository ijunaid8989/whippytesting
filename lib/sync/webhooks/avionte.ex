defmodule Sync.Webhooks.Avionte do
  @moduledoc """
  Process Avionte webhook events.
  Example of events payload:

  {
  "EventName": "talent_created",
  "FrontOfficeTenantId": 6,
  "Resource": "{\"Id\":662,\"CorrelationId\":\"0c015041-e381-448a-b654-a398a025a2e5\"}",
  "ResourceModelType": "Avionte.Commons.CompasEventModel.ResourceModel.TalentResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
  "CorrelationId": "0c015041-e381-448a-b654-a398a025a2e5"
  }

   More information https://developer.avionte.com/docs/webhooks
  """

  alias Sync.Authentication
  alias Sync.Clients.Avionte, as: Client
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Repo
  alias Sync.Workers.Avionte.Utils
  alias Sync.Workers.CustomData
  alias Sync.Workers.CustomData.Converter
  alias Sync.Workers.Whippy

  require Logger

  @parser_module Sync.Clients.Avionte.Parser

  @doc """
  Process Avionte webhook events.

  ## Events
    talent_created: When a talent is created in Avionte. If the talent does not exist in Sync, it will be created and synced to Whippy.
    talent_saved: When a talent is updated in Avionte. The talent will be updated in Sync and synced to Whippy.

    * If the Integration setting `sync_custom_data` is enabled, we will also sync the talent custom object record to Whippy.
  """
  def process_event(event) do
    case get_event_integration(event) do
      %Integration{} = integration -> process_event(integration, event)
      nil -> Logger.error("[Avionte Webhook] Integration not found for event: #{inspect(event)}")
    end
  end

  defp process_event(integration, %{"EventName" => "talent_created"} = event) do
    external_contact_id = get_resource_id(event)

    case Contacts.get_contact_by_external_id(integration.id, external_contact_id) do
      nil -> sync_talent(integration, external_contact_id)
      _ -> :ok
    end
  end

  defp process_event(integration, %{"EventName" => "talent_saved"} = event) do
    external_contact_id = get_resource_id(event)

    sync_talent(integration, external_contact_id)
  end

  # https://developer.avionte.com/docs/talent_merged
  defp process_event(integration, %{"EventName" => "talent_merged", "Resource" => resource}) do
    %{"GoodTalentId" => good_talent_id, "BadTalentId" => bad_talent_id} = Jason.decode!(resource)

    good_talent_id = to_string(good_talent_id)
    bad_talent_id = to_string(bad_talent_id)

    case Contacts.get_contact_by_external_id(integration.id, bad_talent_id) do
      nil -> sync_talent(integration, good_talent_id)
      bad_talent -> overwrite_bad_talent(integration, bad_talent, good_talent_id)
    end
  end

  defp process_event(integration, %{"EventName" => "contact_created"} = event) do
    id = get_resource_id(event)
    external_contact_id = "contact-" <> id

    case Contacts.get_contact_by_external_id(integration.id, external_contact_id) do
      nil -> sync_contact(integration, id)
      _ -> :ok
    end
  end

  defp process_event(integration, %{"EventName" => "contact_updated"} = event) do
    external_contact_id = get_resource_id(event)

    sync_contact(integration, external_contact_id)
  end

  defp process_event(integration, %{"EventName" => "job_created"} = event) do
    id = get_resource_id(event)

    case Integrations.get_integration(integration.id) do
      %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} ->
        Logger.info("[Avionte Webhook] [Integration #{integration.id}] Allowing advanced custom data event job created")

        case sync_job(integration, id) do
          {:ok, _} ->
            {:ok, :processed}

          {:error, reason} = error ->
            Logger.error(
              "[Avionte Webhook] Failed to process job create job_id #{id}, integration_id #{integration.id} error #{inspect(reason)}"
            )

            error
        end

      _ ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Not allowing advanced custom data event job created"
        )

        :ok
    end
  end

  defp process_event(integration, %{"EventName" => "job_updated"} = event) do
    id = get_resource_id(event)

    case Integrations.get_integration(integration.id) do
      %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} ->
        Logger.info("[Avionte Webhook] [Integration #{integration.id}] Allowing advanced custom data event job updated")

        case sync_job(integration, id) do
          {:ok, _} ->
            {:ok, :processed}

          {:error, reason} = error ->
            Logger.error(
              "[Avionte Webhook] Failed to process job update job_id #{id}, integration_id #{integration.id} error #{inspect(reason)}"
            )

            error
        end

      _ ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Not allowing advanced custom data event job updated"
        )

        :ok
    end
  end

  defp process_event(integration, %{"EventName" => "company_updated"} = event) do
    id = get_resource_id(event)

    case Integrations.get_integration(integration.id) do
      %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Allowing advanced custom data event company updated"
        )

        case sync_company(integration, id) do
          {:ok, _} ->
            {:ok, :processed}

          {:error, reason} = error ->
            Logger.error(
              "[Avionte Webhook] Failed to process company updated company_id #{id}, integration_id #{integration.id} error #{inspect(reason)}"
            )

            error
        end

      _ ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Not allowing advanced custom data event company updated"
        )

        :ok
    end
  end

  defp process_event(integration, %{"EventName" => "placement_started"} = event) do
    id = get_placement_resource_id(event)

    case Integrations.get_integration(integration.id) do
      %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Allowing advanced custom data event placement started"
        )

        case sync_placement(integration, id) do
          {:ok, _} ->
            {:ok, :processed}

          {:error, reason} = error ->
            Logger.error(
              "[Avionte Webhook] Failed to process placement started placement_id #{id}, integration_id #{integration.id} error #{inspect(reason)}"
            )

            error
        end

      _ ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Not allowing advanced custom data event placement started"
        )

        :ok
    end
  end

  defp process_event(integration, %{"EventName" => "placement_updated"} = event) do
    id = get_placement_resource_id(event)

    case Integrations.get_integration(integration.id) do
      %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Allowing advanced custom data event placement updated"
        )

        case sync_placement(integration, id) do
          {:ok, _} ->
            {:ok, :processed}

          {:error, reason} = error ->
            Logger.error(
              "[Avionte Webhook] Failed to process placement updated placement_id #{id}, integration_id #{integration.id} error #{inspect(reason)}"
            )

            error
        end

      _ ->
        Logger.info(
          "[Avionte Webhook] [Integration #{integration.id}] Not allowing advanced custom data event placement updated"
        )

        :ok
    end
  end

  defp process_event(_integration, _event), do: :ok

  defp sync_talent(integration, external_contact_id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    attrs = %{
      external_contact_id: external_contact_id,
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id
    }

    with {:ok, [talent]} <- Client.list_talents(api_key, access_token, tenant, talent_ids: [external_contact_id]),
         integration when not is_nil(integration) <- get_modified_integration(integration, talent),
         {:ok, contact} <- Contacts.upsert_external_contact(integration, Map.merge(talent, attrs)) do
      Whippy.Writer.send_contacts_to_whippy(:avionte, integration, [contact])
      maybe_sync_talent_custom_object_record(integration, Repo.reload(contact))
    else
      error ->
        Logger.error("[Avionte Webhook] [Integration #{integration.id}] Failed to sync talent #{inspect(error)}")
    end
  end

  defp get_modified_integration(integration, talent) do
    branches_mapping = Map.get(integration.settings, "branches_mapping", nil)

    case branches_mapping do
      nil ->
        integration

      branches_mapping ->
        mapping =
          Enum.find(branches_mapping, fn mapping -> mapping["office_name"] == talent.external_contact.officeName end)

        Utils.modify_integration(integration, mapping)
    end
  end

  defp maybe_sync_talent_custom_object_record(
         %Integration{settings: %{"sync_custom_data" => true}} = integration,
         contact
       ) do
    with %Contact{whippy_contact_id: whippy_id} when not is_nil(whippy_id) <- contact,
         [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "talent"),
         {:ok, custom_object_record} <-
           CustomData.Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             contact
           ) do
      Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record])
    else
      error ->
        Logger.error(
          "[Avionte Webhook] [Integration #{integration.id}] Failed to sync talent custom object record for contact #{contact.id}: #{inspect(error)}"
        )
    end
  end

  defp maybe_sync_talent_custom_object_record(_, _), do: :ok

  defp overwrite_bad_talent(integration, bad_talent, good_talent_id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    attrs = %{
      external_contact_id: good_talent_id,
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id
    }

    with {:ok, [talent]} <- Client.list_talents(api_key, access_token, tenant, talent_ids: [good_talent_id]),
         {:ok, %{contact: contact}} <-
           Contacts.overwrite_external_contact(integration, bad_talent, Map.merge(talent, attrs)) do
      whippy_payload = Client.Parser.convert_contact_to_whippy_contact(contact)

      if contact.whippy_contact_id do
        Whippy.Writer.update_whippy_contact(integration, contact, whippy_payload, contact.whippy_contact_id)
      else
        Whippy.Writer.send_contacts_to_whippy(:avionte, integration, [contact])
      end

      maybe_sync_talent_custom_object_record(integration, contact)
    end
  end

  defp sync_contact(integration, external_contact_id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    attrs = %{
      external_contact_id: "contact-" <> external_contact_id,
      integration_id: integration.id,
      external_organization_id: integration.external_organization_id
    }

    with {:ok, [avionte_contact]} <- Client.list_contacts(api_key, access_token, tenant, ids: [external_contact_id]),
         integration when not is_nil(integration) <- get_modified_integration(integration, avionte_contact),
         {:ok, contact} <- Contacts.upsert_external_contact(integration, Map.merge(avionte_contact, attrs)) do
      Whippy.Writer.send_contacts_to_whippy(:avionte, integration, [contact])
      maybe_sync_contact_custom_object_record(integration, Repo.reload(contact))
    else
      error ->
        Logger.error("[Avionte Webhook] [Integration #{integration.id}] Failed to sync contact #{inspect(error)}")
    end
  end

  defp maybe_sync_contact_custom_object_record(
         %Integration{settings: %{"sync_custom_data" => true, "allow_advanced_custom_data" => true}} = integration,
         contact
       ) do
    with %Contact{whippy_contact_id: whippy_id} when not is_nil(whippy_id) <- contact,
         [%CustomObject{whippy_custom_object_id: whippy_id} = custom_object] when not is_nil(whippy_id) <-
           Contacts.list_custom_objects_by_external_entity_type(integration, "avionte_contact"),
         {:ok, custom_object_record} <-
           CustomData.Converter.convert_external_resource_to_custom_object_record(
             @parser_module,
             integration,
             custom_object,
             contact
           ) do
      Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record])
    else
      error ->
        Logger.error(
          "[Avionte Webhook] [Integration #{integration.id}] Failed to sync contact custom object record for contact #{contact.id}: #{inspect(error)}"
        )
    end
  end

  defp maybe_sync_contact_custom_object_record(_, _), do: :ok

  defp sync_job(integration, id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    case Client.list_jobs(api_key, access_token, tenant, ids: [id]) do
      {:ok, [job]} ->
        with custom_objects when is_list(custom_objects) and custom_objects != [] <-
               Contacts.list_custom_objects_by_external_entity_type(integration, "jobs"),
             %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
               List.first(custom_objects),
             {:ok, custom_object_record} <-
               Converter.convert_external_resource_to_custom_object_record(
                 @parser_module,
                 integration,
                 custom_object,
                 job
               ),
             :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
          {:ok, :synced}
        else
          [] ->
            {:error, :no_custom_objects}

          {:error, _reason} = error ->
            error
        end

      error ->
        {:error, error}
    end
  end

  defp sync_company(integration, id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    case Client.list_companies(api_key, access_token, tenant, ids: [id]) do
      {:ok, [company]} ->
        with custom_objects when is_list(custom_objects) and custom_objects != [] <-
               Contacts.list_custom_objects_by_external_entity_type(integration, "companies"),
             %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
               List.first(custom_objects),
             {:ok, custom_object_record} <-
               Converter.convert_external_resource_to_custom_object_record(
                 @parser_module,
                 integration,
                 custom_object,
                 company
               ),
             :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
          {:ok, :synced}
        else
          [] ->
            {:error, :no_custom_objects}

          {:error, _reason} = error ->
            error
        end

      error ->
        {:error, error}
    end
  end

  defp sync_placement(integration, id) do
    {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
    {:ok, access_token, integration} = Authentication.Avionte.get_or_regenerate_access_token(integration)
    {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

    case Client.list_placements(api_key, access_token, tenant, ids: [id]) do
      {:ok, [placement]} ->
        with custom_objects when is_list(custom_objects) and custom_objects != [] <-
               Contacts.list_custom_objects_by_external_entity_type(integration, "placements"),
             %CustomObject{whippy_custom_object_id: whippy_id} = custom_object when not is_nil(whippy_id) <-
               List.first(custom_objects),
             {:ok, custom_object_record} <-
               Converter.convert_external_resource_to_custom_object_record(
                 @parser_module,
                 integration,
                 custom_object,
                 placement
               ),
             :ok <- Whippy.Writer.send_custom_object_records_to_whippy(integration, [custom_object_record]) do
          {:ok, :synced}
        else
          [] ->
            {:error, :no_custom_objects}

          {:error, _reason} = error ->
            error
        end

      error ->
        {:error, error}
    end
  end

  defp get_resource_id(%{"Resource" => resource}) do
    resource
    |> Jason.decode!()
    |> Map.get("Id")
    |> to_string()
  end

  defp get_placement_resource_id(%{"Resource" => resource}) do
    resource
    |> Jason.decode!()
    |> Map.get("PlacementId")
    |> to_string()
  end

  defp get_event_integration(event) do
    event["FrontOfficeTenantId"]
    |> to_string()
    |> Integrations.get_integration_by_external_organization_id(:avionte)
  end
end
