defmodule Miner do
  use Application

  import Supervisor.Spec

  alias Miner.{
    Pool,
    Worker
  }

  require Logger

  def start(_, _) do
    Logger.info("Starting Miner")

    children = [
      worker(Pool, []),
      worker(Worker, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
