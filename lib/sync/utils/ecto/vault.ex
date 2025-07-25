defmodule Sync.Utils.Ecto.Vault do
  @moduledoc false
  use Cloak.Vault, otp_app: :sync

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers, default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: decode_env!("CLOAK_KEY")})

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
end
