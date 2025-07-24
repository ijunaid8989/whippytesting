defmodule Sync.Utils.Ecto.Changeset.SchemalessAssocTest do
  use ExUnit.Case

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Branch
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  test "casts a key in a changeset to a struct" do
    cast_params = %{branchAddress: %{street1: "123 Main St", city: "Springfield"}}
    data_and_types_tuple = {%Branch{}, %{branchAddress: :map}}
    changeset = Ecto.Changeset.cast(data_and_types_tuple, cast_params, [:branchAddress])

    assert %Ecto.Changeset{
             action: nil,
             changes: %{
               branchAddress: %Address{
                 street1: "123 Main St",
                 city: "Springfield"
               }
             }
           } = SchemalessAssoc.cast(changeset, :branchAddress, Address)
  end

  test "raises an error when the assoc cannot be casted" do
    # The cast_params are invalid because the street1 is an integer and not a string
    cast_params = %{branchAddress: %{street1: 123, city: "Springfield"}}
    data_and_types_tuple = {%Branch{}, %{branchAddress: :map}}
    changeset = Ecto.Changeset.cast(data_and_types_tuple, cast_params, [:branchAddress])

    assert_raise Ecto.InvalidChangesetError, fn ->
      SchemalessAssoc.cast(changeset, :branchAddress, Address)
    end
  end
end
