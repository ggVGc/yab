defmodule Miner.Worker do
  @behaviour ChainNode.Worker.Listener
  use GenServer

  alias YAB.{
    Chain,
    POW
  }

  require Logger
  require Chain

  defmodule State do
    @type t :: %__MODULE__{active_mining_task: Task.t() | nil}

    @enforce_keys [:active_mining_task]
    defstruct [:active_mining_task]
  end

  def start_link() do
    state = %State{active_mining_task: nil}

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  @impl ChainNode.Worker.Listener
  def on_chain_joined() do
    Logger.info("Miner joined chain")
    GenServer.cast(__MODULE__, :restart_mining)
  end

  @impl ChainNode.Worker.Listener
  def on_new_block() do
    GenServer.cast(__MODULE__, :restart_mining)
  end

  def mining_task(candidate) do
    Logger.info("Mining block")

    mined_block = %{candidate | header: POW.work(candidate.header)}

    Logger.debug("New block mined")

    notify_block_mined()
    {:ok, mined_block}
  end

  defp notify_block_mined() do
    GenServer.cast(__MODULE__, :notify_block_mined)
  end

  defp kill_mining_task_if_active(%State{active_mining_task: nil} = state), do: state

  defp kill_mining_task_if_active(%State{active_mining_task: active_mining_task}) do
    Logger.info("Killing active mining task")
    Task.shutdown(active_mining_task, :brutal_kill)
    %State{active_mining_task: nil}
  end

  defp mine(%State{active_mining_task: active_mining_task}) when not is_nil(active_mining_task),
    do: raise("mining task already active")

  defp mine(%State{} = state) do
    %ChainNode.Worker.State{
      accounts: accounts,
      blocks: [latest_block | _],
      public_key: public_key
    } = ChainNode.Worker.get_state()

    Logger.debug("Pulling new transactions")

    transactions = ChainNode.TransactionPool.get_transactions()

    Logger.debug("Got #{length(transactions)} transactions. Building candidate.")

    {:ok, candidate, _invalid_transactions} =
      Chain.build_candidate(latest_block, public_key, accounts, transactions)

    task =
      Task.Supervisor.async(Miner.TaskSupervisor, fn ->
        mining_task(candidate)
      end)

    %{state | active_mining_task: task}
  end

  def handle_cast(:restart_mining, state) do
    new_state =
      kill_mining_task_if_active(state)
      |> mine()

    {:noreply, new_state}
  end

  def handle_cast(:notify_block_mined, %State{active_mining_task: active_mining_task} = state) do
    {:ok, mined_block} = Task.await(active_mining_task)

    ChainNode.Worker.add_block(mined_block)

    {:noreply, %State{state | active_mining_task: nil}}
  end
end
