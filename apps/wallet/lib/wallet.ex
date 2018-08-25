defmodule Wallet do
  use Application

  import Supervisor.Spec

  alias Wallet.{
    UI
  }

  require Logger

  defmacro private_key(), do: Application.get_env(:wallet, :private_key)
  defmacro public_key(), do: YAB.KeyGenerator.public_from_private(private_key())

  def start(_, _) do
    Logger.info("Starting Wallet")
    ChainNode.set_log_level(:warn)

    children = [
      supervisor(ChainNode, [[listener: UI, public_key: public_key()]])
    ]


    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
