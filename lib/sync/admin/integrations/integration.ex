defmodule Sync.Admin.Integrations.Integration do
  @moduledoc """
  Contains functions to customize the Integration resource in the admin panel.

  The functions here are customized callbacks from Kaffy.
  For more details, see http://hexdocs.pm/kaffy/readme.html
  """

  import Ecto.Query, only: [where: 3]

  alias Oban.Pro.Plugins.DynamicCron
  alias Sync.Authentication
  alias Sync.Clients.Aqore
  alias Sync.Clients.Avionte
  alias Sync.Clients.Crelate
  alias Sync.Clients.Tempworks
  alias Sync.Clients.Whippy
  alias Sync.Integrations
  alias Sync.Integrations.Integration
  alias Sync.Repo
  alias Sync.Webhooks.Tempworks, as: TempworksWebhooks

  require Logger

  @embeds %{
    "avionte_authentication" => Integrations.Clients.Avionte.AuthenticationEmbed,
    "avionte_settings" => Integrations.Clients.Avionte.SettingsEmbed,
    "tempworks_authentication" => Integrations.Clients.Tempworks.IntegrationAuthenticationEmbed,
    "tempworks_settings" => Integrations.Clients.Tempworks.SettingsEmbed,
    "loxo_authentication" => Integrations.Clients.Loxo.IntegrationAuthenticationEmbed,
    "loxo_settings" => Integrations.Clients.Loxo.SettingsEmbed,
    "aqore_authentication" => Integrations.Clients.Aqore.IntegrationAuthenticationEmbed,
    "aqore_settings" => Integrations.Clients.Aqore.SettingsEmbed,
    "hubspot_authentication" => Integrations.Clients.Hubspot.IntegrationAuthenticationEmbed,
    "hubspot_settings" => Integrations.Clients.Hubspot.SettingsEmbed,
    "crelate_authentication" => Integrations.Clients.Crelate.AuthenticationEmbed,
    "crelate_settings" => Integrations.Clients.Crelate.SettingsEmbed
  }

  @default_cron_schedule "15 5 * * *"
  @default_frequent_employee_cron_schedule "*/15 * * * *"
  @default_monthly_cron_schedule "0 3 1 * *"
  @default_cron_paused false
  @client_job_settings %{
    tempworks: %{
      queue: :tempworks,
      worker: Sync.Workers.Tempworks
    },
    avionte: %{
      queue: :avionte,
      worker: Sync.Workers.Avionte
    },
    loxo: %{
      queue: :loxo,
      worker: Sync.Workers.Loxo
    },
    aqore: %{
      queue: :aqore,
      worker: Sync.Workers.Aqore
    },
    hubspot: %{
      queue: :hubspot,
      worker: Sync.Workers.Hubspot
    },
    crelate: %{
      queue: :crelate,
      worker: Sync.Workers.Crelate
    }
  }
  @client_frequent_job_settings %{
    tempworks: %{
      queue: :tempworks_frequent,
      worker: Sync.Workers.TempworksFrequent
    },
    avionte: %{
      queue: :avionte_messages,
      worker: Sync.Workers.AvionteMessages
    },
    loxo: %{
      queue: :loxo,
      worker: Sync.Workers.Loxo
    },
    aqore: %{
      queue: :aqore_messages,
      worker: Sync.Workers.AqoreMessages
    },
    hubspot: %{
      queue: :hubspot,
      worker: Sync.Workers.Hubspot
    },
    crelate: %{
      queue: :crelate,
      worker: Sync.Workers.Crelate
    }
  }

  def resource_actions(conn) do
    # Get the integration from the URL params
    integration_id = get_integration_id_from_conn(conn)

    # Get the integration to check its client
    integration =
      case integration_id do
        nil -> nil
        id -> Integrations.get_integration(id)
      end

    [
      test_connection: %{
        name: "Test Connection",
        action: fn
          _c, %Integration{client: :tempworks} = integration ->
            test_tempworks_connection(integration)

          _c, %Integration{client: :avionte} = integration ->
            test_avionte_connection(integration)

          _c, %Integration{client: :crelate} = integration ->
            test_crelate_connection(integration)

          _c, %Integration{client: :aqore} = integration ->
            test_aqore_connection(integration)

          _c, %Integration{client: client} = integration ->
            {:error, integration, "Connection testing not implemented for #{client} yet"}
        end
      },
      schedule_full_sync: %{
        name: "Create Full Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_or_update_full_sync_cron_job(integration)
        end
      },
      schedule_daily_sync: %{
        name: "Create/Update Daily Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_or_update_daily_sync_cron_job(integration)
        end
      },
      schedule_messages_sync: %{
        name: "Create/Update Messages Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_or_update_messages_sync_cron_job(integration)
        end
      },
      schedule_monthly_sync: %{
        name: "Create/Update Monthly Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_or_update_monthly_sync_cron_job(integration)
        end
      },
      run_custom_data_sync: %{
        name: "Run Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_custom_data_sync_job(integration)
        end
      }
    ] ++ client_specific_jobs(integration.client)
  end

  def client_specific_jobs(:tempworks) do
    [
      schedule_frequent_employee_sync: %{
        name: "Create/Update Frequent Employee Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_or_update_frequent_employee_sync_cron_job(integration)
        end
      },
      run_employee_custom_data_sync: %{
        name: "Run Employee Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_employee_custom_data_sync_job(integration)
        end
      },
      run_assignment_custom_data_sync: %{
        name: "Run Assignment Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_assignment_custom_data_sync_job(integration)
        end
      },
      run_job_order_custom_data_sync: %{
        name: "Run Job Order Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_job_order_custom_data_sync_job(integration)
        end
      },
      run_tempworks_contacts_custom_data_sync: %{
        name: "Run Tempworks Contacts Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_tempworks_contacts_custom_data_sync_job(integration)
        end
      },
      run_customers_custom_data_sync: %{
        name: "Run Customers Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_customers_custom_data_sync_job(integration)
        end
      }
    ]
  end

  def client_specific_jobs(:avionte) do
    [
      run_talents_custom_data_sync: %{
        name: "Run Talent Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_talents_custom_data_sync_job(integration)
        end
      },
      run_avionte_contacts_custom_data_sync: %{
        name: "Run Avionte Contacts Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_avionte_contacts_custom_data_sync_job(integration)
        end
      },
      run_avionte_companies_custom_data_sync: %{
        name: "Run Avionte Companies Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_avionte_companies_custom_data_sync_job(integration)
        end
      },
      run_avionte_placements_custom_data_sync: %{
        name: "Run Avionte Placements Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_avionte_placements_custom_data_sync_job(integration)
        end
      },
      run_avionte_jobs_custom_data_sync: %{
        name: "Run Avionte Jobs Custom Data Syncing Job",
        action: fn _c, %Integration{} = integration ->
          create_avionte_jobs_custom_data_sync_job(integration)
        end
      }
    ]
  end

  def client_specific_jobs(_client), do: []

  def index(_) do
    [
      integration: %{type: :string, label: "Integration Name"},
      whippy_organization_id: %{type: :string, label: "Whippy Organization ID"},
      external_organization_id: %{type: :string, label: "External Organization ID"},
      settings: %{type: :map, label: "Integration Settings"}
    ]
  end

  def form_fields(_) do
    [
      integration: %{type: :string, label: "Integration Name"},
      whippy_organization_id: %{type: :string, label: "Whippy Organization ID"},
      external_organization_id: %{type: :string, label: "External Organization ID"},
      client: %{
        choices: [
          {"Avionte", :avionte},
          {"Tempworks", :tempworks},
          {"Loxo", :loxo},
          {"Aqore", :aqore},
          {"Hubspot", :hubspot},
          {"Crelate", :crelate}
        ]
      },
      authentication: %{
        type: :map,
        label: "Integration Authentication",
        help_text: map_field_help_text(:authentication)
      },
      settings: %{
        type: :map,
        label: "Integration Settings",
        help_text: map_field_help_text(:settings)
      }
    ]
  end

  def custom_links(_schema) do
    [
      %{
        name: "Oban Dashboard",
        url: "/oban",
        location: :top,
        icon: "bolt",
        full_icon: nil
      }
    ]
  end

  def create_changeset(schema, %{"authentication" => _authentication} = attrs) do
    attrs = Map.update!(attrs, "authentication", &Jason.decode!(&1))

    Integration.changeset(schema, attrs)
  end

  def create_changeset(schema, attrs) do
    Integration.changeset(schema, attrs)
  end

  def update_changeset(entry, %{"authentication" => _authentication} = attrs) do
    attrs = Map.update!(attrs, "authentication", &Jason.decode!(&1))

    Integration.changeset(entry, attrs)
  end

  def update_changeset(entry, attrs) do
    Integration.changeset(entry, attrs)
  end

  ##################
  #    Helpers     #
  ##################

  defp create_or_update_full_sync_cron_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    case get_job(integration_id, "full_sync") do
      nil ->
        Oban.insert(worker.new(%{integration_id: integration_id, type: "full_sync"}))

      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_or_update_daily_sync_cron_job(
         %Integration{id: integration_id, client: integration_client, settings: integration_settings} = integration
       ) do
    integration_settings = integration_settings || %{}
    cron_schedule = Map.get(integration_settings, "daily_sync_at", @default_cron_schedule)

    paused = Map.get(integration_settings, "paused", @default_cron_paused)

    %{queue: queue, worker: worker} = get_queue_and_worker(integration_client)

    case get_cron_job(integration_id, "daily-sync") do
      nil ->
        DynamicCron.insert([
          {cron_schedule, worker, name: "integration-#{integration_id}-daily-sync",
           args: %{integration_id: integration_id, type: "daily_sync"}, queue: queue, paused: paused}
        ])

      _ ->
        DynamicCron.update("integration-#{integration_id}-daily-sync",
          expression: cron_schedule,
          worker: worker,
          name: "integration-#{integration_id}-daily-sync",
          args: %{integration_id: integration_id, type: "daily_sync"},
          queue: queue,
          paused: paused
        )
    end

    {:ok, integration}
  end

  defp create_or_update_frequent_employee_sync_cron_job(
         %Integration{id: integration_id, client: integration_client, settings: integration_settings} = integration
       ) do
    integration_settings = integration_settings || %{}
    cron_schedule = Map.get(integration_settings, "employee_sync_at", @default_frequent_employee_cron_schedule)

    paused = Map.get(integration_settings, "paused", @default_cron_paused)

    %{queue: queue, worker: worker} = get_queue_and_worker_for_frequent_processing(integration_client)

    case get_cron_job(integration_id, "employee-frequent-sync") do
      nil ->
        DynamicCron.insert([
          {cron_schedule, worker, name: "integration-#{integration_id}-employee-frequent-sync",
           args: %{integration_id: integration_id, type: "employee_frequent_sync"}, queue: queue, paused: paused}
        ])

      _ ->
        DynamicCron.update("integration-#{integration_id}-employee-frequent-sync",
          expression: cron_schedule,
          worker: worker,
          name: "integration-#{integration_id}-employee-frequent-sync",
          args: %{integration_id: integration_id, type: "employee_frequent_sync"},
          queue: queue,
          paused: paused
        )
    end

    {:ok, integration}
  end

  defp create_or_update_messages_sync_cron_job(
         %Integration{id: integration_id, client: integration_client, settings: integration_settings} = integration
       ) do
    integration_settings = integration_settings || %{}
    cron_schedule = Map.get(integration_settings, "messages_sync_at", @default_cron_schedule)

    paused = Map.get(integration_settings, "paused", @default_cron_paused)

    %{queue: queue, worker: worker} = get_queue_and_worker_for_frequent_processing(integration_client)

    case get_cron_job(integration_id, "messages-sync") do
      nil ->
        DynamicCron.insert([
          {cron_schedule, worker, name: "integration-#{integration_id}-messages-sync",
           args: %{integration_id: integration_id, type: "messages_sync"}, queue: queue, paused: paused}
        ])

      _ ->
        DynamicCron.update("integration-#{integration_id}-messages-sync",
          expression: cron_schedule,
          worker: worker,
          name: "integration-#{integration_id}-messages-sync",
          args: %{integration_id: integration_id, type: "messages_sync"},
          queue: queue,
          paused: paused
        )
    end

    {:ok, integration}
  end

  defp create_or_update_monthly_sync_cron_job(
         %Integration{id: integration_id, client: integration_client, settings: integration_settings} = integration
       ) do
    integration_settings = integration_settings || %{}
    cron_schedule = Map.get(integration_settings, "monthly_sync_at", @default_monthly_cron_schedule)

    paused = Map.get(integration_settings, "paused", @default_cron_paused)

    %{queue: queue, worker: worker} = get_queue_and_worker(integration_client)

    case get_cron_job(integration_id, "monthly-sync") do
      nil ->
        DynamicCron.insert([
          {cron_schedule, worker, name: "integration-#{integration_id}-monthly-sync",
           args: %{integration_id: integration_id, type: "monthly_sync"}, queue: queue, paused: paused}
        ])

      _ ->
        DynamicCron.update("integration-#{integration_id}-monthly-sync",
          expression: cron_schedule,
          worker: worker,
          name: "integration-#{integration_id}-monthly-sync",
          args: %{integration_id: integration_id, type: "monthly_sync"},
          queue: queue,
          paused: paused
        )
    end

    {:ok, integration}
  end

  # This is not a cron job, but a one-time job
  defp create_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_employee_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :tempworks <- integration_client,
         nil <- get_job(integration_id, "employee_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "employee_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_assignment_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :tempworks <- integration_client,
         nil <- get_job(integration_id, "assignment_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "assignment_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_job_order_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :tempworks <- integration_client,
         nil <- get_job(integration_id, "job_order_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "job_order_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_tempworks_contacts_custom_data_sync_job(
         %Integration{id: integration_id, client: integration_client} = integration
       ) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :tempworks <- integration_client,
         nil <- get_job(integration_id, "tempworks_contacts_custom_data_sync_job") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "tempworks_contacts_custom_data_sync_job"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_customers_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :tempworks <- integration_client,
         nil <- get_job(integration_id, "customers_custom_data_sync_job") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "customers_custom_data_sync_job"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_talents_custom_data_sync_job(%Integration{id: integration_id, client: integration_client} = integration) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "talents_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "talents_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_avionte_contacts_custom_data_sync_job(
         %Integration{id: integration_id, client: integration_client} = integration
       ) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "avionte_contacts_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "avionte_contacts_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_avionte_companies_custom_data_sync_job(
         %Integration{id: integration_id, client: integration_client} = integration
       ) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "avionte_companies_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "avionte_companies_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_avionte_placements_custom_data_sync_job(
         %Integration{id: integration_id, client: integration_client} = integration
       ) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "avionte_placements_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "avionte_placements_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp create_avionte_jobs_custom_data_sync_job(
         %Integration{id: integration_id, client: integration_client} = integration
       ) do
    %{worker: worker} = get_queue_and_worker(integration_client)

    with :avionte <- integration_client,
         nil <- get_job(integration_id, "avionte_jobs_custom_data_sync") do
      Oban.insert(worker.new(%{integration_id: integration_id, type: "avionte_jobs_custom_data_sync"}))
    else
      _ ->
        :ignore
    end

    {:ok, integration}
  end

  defp get_cron_job(integration_id, type) do
    Oban.Pro.Cron
    |> where([cron], cron.name == ^"integration-#{integration_id}-#{type}")
    |> Repo.one()
  end

  defp get_job(integration_id, type) do
    Oban.Job
    |> where(
      [j],
      j.state not in ["cancelled", "discarded", "completed"] and
        fragment("args->>'integration_id' = ?", ^integration_id) and
        fragment("args->>'type' = ?", ^type)
    )
    |> Repo.one()
  end

  defp get_queue_and_worker(client) do
    @client_job_settings[client]
  end

  defp get_queue_and_worker_for_frequent_processing(client) do
    @client_frequent_job_settings[client]
  end

  # Generates help text for the map fields based on the client field.
  # It visualizes what fields are expected in the map field and their types.
  defp map_field_help_text(field) do
    Enum.reduce(["avionte", "tempworks", "loxo", "aqore", "hubspot", "crelate"], "", fn client, acc ->
      schema = @embeds["#{client}_#{field}"]
      fields = :fields |> schema.__schema__() |> Enum.reject(&(schema.__schema__(:type, &1) == {:array, :map}))

      example_map =
        Map.new(fields, fn field ->
          type = schema.__schema__(:type, field)
          {field, parse_type(type)}
        end)

      acc <> String.capitalize(client) <> ": " <> Jason.encode!(example_map) <> "\n"
    end)
  end

  defp parse_type({:array, inner_type}), do: "array of #{inner_type}"
  defp parse_type(other), do: "#{other}"

  ###################
  # Test Connection #
  ###################

  defp test_tempworks_connection(%Integration{} = integration) do
    case Authentication.Tempworks.get_or_regenerate_service_token(integration) do
      {:ok, %Integration{authentication: %{"access_token" => access_token}} = integration} ->
        case Tempworks.list_branches(access_token, limit: 1) do
          {:ok, _} -> {:ok, integration}
          {:error, reason} -> {:error, integration, "Connection unsuccessful: #{inspect(reason)}"}
        end

      error ->
        {:error, integration, "Authentication unsuccessful: #{inspect(error)}"}
    end
  end

  defp test_avionte_connection(%Integration{} = integration) do
    case Authentication.Avionte.get_or_regenerate_access_token(integration) do
      {:ok, access_token, integration} ->
        {:ok, api_key} = Authentication.Avionte.get_api_key(integration)
        {:ok, tenant} = Authentication.Avionte.get_tenant(integration)

        case Avionte.list_talent_ids(api_key, access_token, tenant, limit: 1) do
          {:ok, _} -> {:ok, integration}
          {:error, reason} -> {:error, integration, "Connection unsuccessful: #{inspect(reason)}"}
        end

      {:error, error} ->
        {:error, integration, "Authentication unsuccessful: #{inspect(error)}"}
    end
  end

  defp test_crelate_connection(%Integration{} = integration) do
    {:ok, api_key} = Authentication.Crelate.get_api_key(integration)

    case Crelate.get_whippy_sms_id(api_key, integration.settings["use_production_url"]) do
      {:ok, message_id} ->
        Integrations.update_integration(integration, %{settings: %{"crelate_messages_action_id" => message_id}})

        {:ok, integration}

      {:error, reason} ->
        {:error, integration, "Connection unsuccessful: #{inspect(reason)}"}
    end
  end

  defp test_aqore_connection(
         %Integration{authentication: %{"requests_made" => _latest_requests_made} = authentication} = integration
       ) do
    case Authentication.Aqore.generate_access_token(integration) do
      {:ok, access_token} ->
        authentication
        |> Map.put("access_token", access_token)
        |> Map.put("requests_made", 1)
        |> then(&Integrations.update_integration(integration, %{authentication: &1}))

        {:ok, details} = Authentication.Aqore.get_integration_details(integration)

        case Aqore.list_users(details, 1, 0, :full_sync) do
          {:ok, _} -> {:ok, integration}
          {:error, reason} -> {:error, integration, "Connection unsuccessful: #{inspect(reason)}"}
        end

      error ->
        {:error, integration, "Authentication unsuccessful: #{inspect(error)}"}
    end
  end

  #####################
  #    Callbacks     #
  #####################
  def after_insert(_conn, integration) do
    case Whippy.create_integration(integration.authentication["whippy_api_key"], integration) do
      {:ok, _} ->
        TempworksWebhooks.maybe_subscribe_to_webhooks(integration)
        {:ok, integration}

      {:error, error} ->
        {:error, integration, "Failed to create integration in Whippy: #{inspect(error)}"}
    end
  end

  def after_update(_conn, integration) do
    TempworksWebhooks.maybe_subscribe_to_webhooks(integration)
    {:ok, integration}
  end

  # Helper function to extract integration ID from conn
  defp get_integration_id_from_conn(conn) do
    case conn.path_params do
      %{"id" => id} -> id
      _ -> nil
    end
  end
end
