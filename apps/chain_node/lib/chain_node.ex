defmodule ChainNode do
  use Supervisor

  import Supervisor.Spec

  alias ChainNode.{
    Worker,
    NodeList,
    TransactionPool
  }

  require Logger

  def start_link(listener) do
    Supervisor.start_link(__MODULE__, listener, name: __MODULE__)
  end

  def init(listener) do
    Logger.info("Starting ChainNode")

    children = [
      worker(TransactionPool, []),
      worker(Worker, [listener]),
      worker(NodeList, [])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def set_log_level(level) do
    Logger.configure(level: level)
  end
end
