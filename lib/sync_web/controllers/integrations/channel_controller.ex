defmodule SyncWeb.Integrations.ChannelController do
  use SyncWeb, :controller

  alias Sync.Channels
  alias Sync.Channels.Channel

  def update(conn, %{
        "integration_id" => integration_id,
        "external_channel_id" => external_channel_id,
        "whippy_channel_id" => whippy_channel_id
      }) do
    with {:ok, _integration_id} <- Ecto.UUID.dump(integration_id),
         {:ok, _whippy_channel_id} <- Ecto.UUID.dump(whippy_channel_id) do
      handle_channel_update(conn, integration_id, external_channel_id, whippy_channel_id)
    else
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{description: "Invalid params - integration_id or whippy_channel_id is not a valid UUID"}]})
    end
  end

  def handle_channel_update(conn, integration_id, external_channel_id, whippy_channel_id) do
    case Channels.get_available_external_integration_channel(integration_id, external_channel_id) do
      nil ->
        error_message = "Available Channel #{external_channel_id} not found for integration #{integration_id}"

        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{description: error_message}]})

      %Channel{whippy_channel_id: existing_whippy_channel_id} when existing_whippy_channel_id == whippy_channel_id ->
        message =
          "Branch #{external_channel_id} is already synced to whippy channel #{whippy_channel_id} for integration #{integration_id}"

        conn
        |> put_status(:ok)
        |> json(%{message: message})

      %Channel{whippy_channel_id: existing_whippy_channel_id} = channel
      when existing_whippy_channel_id != whippy_channel_id and is_binary(existing_whippy_channel_id) ->
        message =
          "Branch #{external_channel_id} is already synced to another Whippy channel " <>
            "#{existing_whippy_channel_id} for integration #{integration_id}. " <>
            "Creating a new channel associated with #{whippy_channel_id}."

        {:ok, channel} =
          channel
          |> Map.from_struct()
          |> Map.put(:whippy_channel_id, whippy_channel_id)
          |> Channels.create_channel()

        conn
        |> put_status(:ok)
        |> json(%{channel: channel, message: message})

      %Channel{whippy_channel_id: nil} = channel ->
        case Channels.associate_whippy_channel(channel, whippy_channel_id) do
          {:ok, channel} ->
            message =
              "Synced branch #{external_channel_id} to Whippy channel #{whippy_channel_id} " <>
                "for integration #{integration_id}"

            conn
            |> put_status(:ok)
            |> json(%{channel: channel, message: message})

          {:error, message} when is_binary(message) ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: [%{description: message}]})

          {:error, _changeset} ->
            error_message = "Whippy Channel #{whippy_channel_id} could not be associated to Branch #{external_channel_id}"

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: [%{description: error_message}]})
        end
    end
  end
end
