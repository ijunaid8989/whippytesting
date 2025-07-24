defmodule Sync.Workers.Utils do
  @moduledoc """
  Contains utility functions reused across workers.
  """

  alias Sync.Activities
  alias Sync.Activities.Activity
  alias Sync.Authentication
  alias Sync.Channels
  alias Sync.Clients
  alias Sync.Contacts
  alias Sync.Contacts.Contact
  alias Sync.Contacts.CustomObject
  alias Sync.Contacts.CustomObjectRecord
  alias Sync.Contacts.CustomProperty
  alias Sync.Integrations
  alias Sync.Integrations.Integration

  @error_types ~w[whippy integration]
  @failed_message_statuses ~w[failed delivery_failed sending_failed]

  def log_activity_error(%Activity{errors: errors} = activity, error_type, error) when error_type in @error_types do
    updated_errors = append_error(error_type, errors, error)

    Activities.update_activity_errors(activity, updated_errors)
  end

  def log_contact_error(%Contact{errors: errors} = contact, error_type, error) when error_type in @error_types do
    updated_errors = append_error(error_type, errors, error)

    Contacts.update_contact_errors(contact, updated_errors)
  end

  def log_custom_property_error(%CustomProperty{errors: errors} = custom_property, error_type, error)
      when error_type in @error_types do
    updated_errors = append_error(error_type, errors, error)
    update_params = %{errors: updated_errors, should_sync_to_whippy: false}

    Contacts.update_custom_property(custom_property, update_params)
  end

  def log_custom_object_error(%CustomObject{errors: errors} = custom_object, error_type, error)
      when error_type in @error_types do
    updated_errors = append_error(error_type, errors, error)

    Contacts.update_custom_object(custom_object, %{errors: updated_errors})
  end

  def log_custom_object_record_error(%CustomObjectRecord{errors: errors} = custom_object_record, error_type, error)
      when error_type in @error_types do
    updated_errors = append_error(error_type, errors, error)
    update_params = %{errors: updated_errors, should_sync_to_whippy: false}

    Contacts.update_custom_object_record_after_failure(custom_object_record, update_params)
  end

  defp append_error(error_type, errors, new_error) do
    update_in(errors, [error_type], fn
      nil ->
        [%{"at" => DateTime.utc_now(), "error" => new_error}]

      existing_errors ->
        existing_errors ++ [%{"at" => DateTime.utc_now(), "error" => new_error}]
    end)
  end

  ########################
  ##   Job Scheduling   ##
  ########################

  @doc """
  Adds a job to a workflow with support for dependency management and uniqueness constraints.

  ## Parameters

    - `workflow` (`Workflow.t()`):
      The workflow object to which the job will be added.

    - `worker` (`atom()`):
      The worker module responsible for processing the job.

    - `subworkers_and_types` (`map()`):
      A mapping of subworker modules to the list of job types they handle.

    - `type` (`atom()`):
      The type of the job to add. This must match one of the types defined in the `subworkers_and_types` mapping.

    - `args` (`map()`):
      A map of arguments to pass to the job. This map will be augmented with the `type` and uniqueness configuration.

    - `deps` (`list()`):
      A list of dependencies (other jobs in the workflow) that this job depends on. Defaults to an empty list.

  ## Returns

    - `Workflow.t()`:
      The updated workflow object with the new job added.

  ## Uniqueness Constraints

  The job is made unique based on the following constraints:
    - **Period:** Jobs with the same arguments and type will not be duplicated within a period of 5 minutes.
    - **States:** Uniqueness is enforced for jobs in the `:available` and `:scheduled` states.
    - **Fields:** Uniqueness is determined based on the `args` of the job.

  ## Raises

    - `ArgumentError`:
      Raised if the specified `type` is not supported by any of the subworker modules provided.

  ## Examples

  ### Adding a Job Without Dependencies

  ```elixir
  workflow = Avionte.new_workflow()
      subworkers_and_types = %{Talents => [:pull_talents, :push_talents], TalentActivities => [:pull_messages, :push_talent_activities]}

      add_job(workflow, Avionte, subworkers_and_types, :push_talents, %{integration_id: "1234"}, [:pull_talents])

  workflow
  |> add_job(MyWorker, %{SubWorker => [:type_a, :type_b]}, :type_a, %{"integration_id" => 123})
  ```
  """
  @spec add_job(Workflow.t(), atom(), map(), atom(), map(), list()) :: Workflow.t()
  def add_job(workflow, worker, subworkers_and_types, type, args, deps \\ []) do
    case find_subworker_module(subworkers_and_types, type) do
      nil ->
        raise ArgumentError, "Unsupported job type: #{type}"

      subworker ->
        unique_attrs = [
          period: 5 * 60,
          states: ~w(available scheduled retryable executing)a,
          keys: ~w(integration_id type)a
        ]

        args
        |> Map.put("type", "#{type}")
        |> subworker.new(unique: unique_attrs)
        |> then(&worker.add(workflow, type, &1, deps: deps))
    end
  end

  defp find_subworker_module(worker_and_types, type),
    do: Enum.find_value(worker_and_types, nil, fn {module, types} -> if type in types, do: module end)

  @doc """
  Invokes a function that adds custom data jobs to the workflow if the integration is configured to sync custom data.

  ## Parameters
  - `workflow` - The workflow to add the custom data jobs to.
  - `integration_id` - The ID of the integration to check for custom data syncing.
  - `add_custom_data_func` - A function that accepts the workflow and integration ID and adds the custom data jobs.

  ## Examples
    iex> workflow = Tempworks.new_workflow()
    iex> integration_id = "1234"
    iex> func = fn workflow, integration_id -> add_job(workflow, :pull_custom_objects_from_whippy, %{integration_id: integration_id}) end
    iex> maybe_add_custom_data_jobs(workflow, integration_id, &func/2)
  """
  def maybe_add_custom_data_jobs(workflow, integration_id, add_custom_data_func) do
    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"sync_custom_data" => true}} ->
        add_custom_data_func.(workflow, integration_id)

      _ ->
        workflow
    end
  end

  def maybe_send_contacts_to_external_integrations(
        workflow,
        %{integration_id: integration_id} = params,
        send_contacts,
        do_not_send_contacts,
        worker,
        subworkers_and_types
      ) do
    case Integrations.get_integration(integration_id) do
      %Integration{settings: %{"send_contacts_to_external_integrations" => true}} ->
        add_jobs(workflow, params, send_contacts, worker, subworkers_and_types)

      _ ->
        add_jobs(workflow, params, do_not_send_contacts, worker, subworkers_and_types)
    end
  end

  defp add_jobs(workflow, params, jobs, worker, subworkers_and_types) do
    Enum.reduce(jobs, workflow, fn {job, dependencies}, acc ->
      add_job(acc, worker, subworkers_and_types, job, params, dependencies)
    end)
  end

  ########################
  ## Message Formatting ##
  ########################

  def build_message_body(
        %Activity{whippy_activity: whippy_message},
        acc,
        %Contact{name: contact_name},
        %Integration{} = integration,
        delimiter \\ "\n\n"
      ) do
    user = whippy_message["user"]
    body = update_message_body_with_delimiter(whippy_message, delimiter)
    status = parse_whippy_delivery_status(whippy_message["delivery_status"])

    timezone =
      get_message_body_timezone(integration, whippy_message["channel_id"])

    time = parse_whippy_timestamp(whippy_message["created_at"], timezone)

    case whippy_message["direction"] do
      "OUTBOUND" ->
        acc <> "[#{user}] [#{time}]#{status} #{body}#{delimiter}"

      "INBOUND" ->
        acc <> "[#{contact_name}] [#{time}]#{status} #{body}#{delimiter}"

      "NOTE" ->
        acc <> "[#{user}] [#{time}] [NOTE] #{body}#{delimiter}"
    end
  end

  def build_message_body_for_crelate(
        %Activity{whippy_activity: whippy_message},
        acc,
        %Contact{name: contact_name},
        %Integration{} = integration,
        delimiter \\ "\n\n"
      ) do
    user = whippy_message["user"]
    body = update_message_body_with_delimiter(whippy_message, delimiter)
    status = parse_whippy_delivery_status(whippy_message["delivery_status"])

    timezone =
      get_message_body_timezone(integration, whippy_message["channel_id"])

    time = parse_whippy_timestamp(whippy_message["created_at"], timezone)

    case whippy_message["direction"] do
      "OUTBOUND" ->
        acc <> "<h4>#{user}</h4><p>#{time} #{status}</p><p>#{body}</p>"

      "INBOUND" ->
        acc <>
          "<h4>#{contact_name}</h4><p>#{time} #{status}</p><p>#{body}</p>"

      "NOTE" ->
        acc <> "<h4>#{user}</h4><p>#{time} [NOTE]</p><p>#{body}</p>"
    end
  end

  defp parse_whippy_delivery_status(status) when status in @failed_message_statuses, do: " [Failed to Deliver]"

  defp parse_whippy_delivery_status(_status), do: ""

  defp parse_whippy_timestamp(iso8601_time, timezone) do
    timezone = timezone || "Etc/UTC"
    {:ok, datetime} = Timex.parse(iso8601_time, "{ISO:Extended}")
    # shift to timezone
    {:ok, time_with_zone} = DateTime.shift_zone(datetime, timezone)

    {:ok, readable_timestamp} =
      Timex.format(time_with_zone, "{WDshort}, {D} {Mshort} {YY} {h12}:{m} {AM} - {Zabbr}")

    readable_timestamp
  end

  defp update_message_body_with_delimiter(%{"translated_body" => translated_body}, delimiter)
       when is_binary(translated_body) and byte_size(translated_body) > 0 do
    apply_delimiter(translated_body, delimiter)
  end

  defp update_message_body_with_delimiter(%{"body" => body}, delimiter) when is_binary(body) and byte_size(body) > 0 do
    apply_delimiter(body, delimiter)
  end

  defp apply_delimiter(body, delimiter), do: String.replace(body, ~r/\n/, delimiter)

  defp get_message_body_timezone(%Integration{settings: settings} = integration, whippy_channel_id) do
    case Channels.get_integration_whippy_channels_with_timezone(integration.id, whippy_channel_id) do
      channels when is_list(channels) and channels != [] ->
        # find channel with timezone
        channel = Enum.find(channels, fn channel -> channel.timezone end)

        channel.timezone || settings["default_messages_timezone"] || "Etc/UTC"

      _not_found ->
        whippy_timezone = get_whippy_channel_timezone(integration, whippy_channel_id)
        whippy_timezone || settings["default_messages_timezone"] || "Etc/UTC"
    end
  end

  defp get_whippy_channel_timezone(%Integration{} = integration, whippy_channel_id) do
    {:ok, api_key} = Authentication.Whippy.get_api_key(integration)

    case Clients.Whippy.get_channel(api_key, whippy_channel_id) do
      {:ok, %Clients.Whippy.Model.Channel{timezone: timezone}} ->
        timezone

      _error ->
        nil
    end
  end

  @doc """
  """
  def generate_conversation_link(message_id, conversation_id, organization_id) do
    whippy_dashboard_url = Application.get_env(:sync, :whippy_dashboard)

    "#{whippy_dashboard_url}/organizations/#{organization_id}/all/open/#{conversation_id}?message_id=#{message_id}"
  end
end
