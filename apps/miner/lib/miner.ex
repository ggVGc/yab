defmodule Miner do
  use Application

  import Supervisor.Spec

  alias Miner.{
    Worker
  }

  require Logger

  def start(_, _) do
    Logger.info("Starting Miner")

    children = [
      supervisor(ChainNode, [[listener: Worker]]),
      worker(Worker, []),
      {Task.Supervisor, name: Miner.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
