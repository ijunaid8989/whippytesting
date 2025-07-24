defmodule Sync.Utils.Ecto.EncryptedMap do
  @moduledoc false
  use Cloak.Ecto.Map, vault: Sync.Utils.Ecto.Vault
end
