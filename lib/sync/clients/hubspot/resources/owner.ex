defmodule Sync.Clients.Hubspot.Resources.Owner do
  @moduledoc false
  alias Sync.Clients.Hubspot.Parser

  @api_path "/crm/v3/owners"
  @limit 100

  def pull_owners(client, cursor \\ "") do
    params = build_params(cursor)

    :get
    |> client.(
      @api_path <>
        "?" <>
        URI.encode_query(params),
      %{},
      false
    )
    |> process_owners_response()
  end

  defp process_owners_response(response) do
    case response do
      %{"results" => owners, "paging" => %{"next" => %{"after" => cursor}}} ->
        {:ok, transform_hubspot_owners(owners), cursor}

      %{"results" => owners} ->
        {:ok, transform_hubspot_owners(owners)}
    end
  end

  defp transform_hubspot_owners(owners) do
    Enum.map(owners, &Parser.parse(:hubspot_owner, &1))
  end

  defp build_params(cursor) when byte_size(cursor) > 0 do
    %{
      "limit" => @limit,
      "archived" => false,
      "after" => cursor
    }
  end

  defp build_params(_cursor) do
    %{
      "limit" => @limit,
      "archived" => false
    }
  end
end
