defmodule Miner.Worker do
  @behaviour ChainNode.Worker.Listener
  use GenServer

  alias YAB.{
    Chain,
    POW,
    SignedTransaction
  }

  require Logger
  require Chain

  defmodule State do
    @type t :: %__MODULE__{active_mining_task: Task.t() | nil}

    @enforce_keys [:active_mining_task, :auto_mining]
    defstruct [:active_mining_task, :auto_mining]
  end

  def start_link() do
    state = %State{active_mining_task: nil, auto_mining: false}

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl ChainNode.Worker.Listener
  def on_chain_joined() do
    Logger.info("Miner joined chain")
  end

  @impl ChainNode.Worker.Listener
  def on_new_block() do
    GenServer.cast(__MODULE__, :on_new_block)
  end

  def mine_block() do
    GenServer.cast(__MODULE__, :mine_block)
  end

  def set_auto_mine(flag) when is_boolean(flag) do
    GenServer.call(__MODULE__, {:set_auto_mine, flag})
  end

  defp mining_task(candidate) do
    Logger.info("Mining block")

    mined_block = %{candidate | header: POW.work(candidate.header)}

    Logger.debug("New block mined")

    GenServer.cast(__MODULE__, :notify_block_mined)
    {:ok, mined_block}
  end

  defp kill_mining_task_if_active(%State{active_mining_task: nil} = state), do: state

  defp kill_mining_task_if_active(%State{active_mining_task: active_mining_task} = state) do
    Logger.info("Killing active mining task")
    Task.shutdown(active_mining_task, :brutal_kill)
    %State{state | active_mining_task: nil}
  end

  defp start_mining_task(%State{active_mining_task: active_mining_task})
       when not is_nil(active_mining_task),
       do: raise("mining task already active")

  defp start_mining_task(%State{} = state) do
    %ChainNode.Worker.State{
      accounts: accounts,
      blocks: [latest_block | _],
      public_key: public_key
    } = ChainNode.Worker.get_state()

    Logger.debug("Pulling new transactions")

    transactions = ChainNode.TransactionPool.get_transactions()

    Logger.debug("Got #{length(transactions)} transactions. Building candidate.")

    {:ok, candidate, invalid_transactions} =
      Chain.build_candidate(latest_block, public_key, accounts, transactions)

    Enum.each(invalid_transactions, fn {%SignedTransaction{}, _} = invalid ->
      Logger.warn("Skipping invalid transaction: #{inspect(invalid)}")
    end)

    task =
      Task.Supervisor.async(Miner.TaskSupervisor, fn ->
        mining_task(candidate)
      end)

    %{state | active_mining_task: task}
  end

  @impl GenServer
  def handle_call({:set_auto_mine, flag}, _, %State{} = state) when is_boolean(flag) do
    if flag do
      Process.send_after(self(), :restart_mining, 1000)
    end

    {:reply, :ok, %State{state | auto_mining: flag}}
  end

  @impl GenServer
  def handle_cast(:mine_block, state) do
    new_state =
      kill_mining_task_if_active(state)
      |> start_mining_task()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:on_new_block, %State{auto_mining: auto_mining} = state) do
    new_state =
      if auto_mining do
        kill_mining_task_if_active(state)
        |> start_mining_task()
      else
        kill_mining_task_if_active(state)
      end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:notify_block_mined, %State{active_mining_task: active_mining_task} = state) do
    {:ok, mined_block} = Task.await(active_mining_task)

    ChainNode.Worker.add_block(mined_block)

    {:noreply, %State{state | active_mining_task: nil}}
  end

  @impl GenServer
  def handle_info(:restart_mining, state) do
    new_state =
      kill_mining_task_if_active(state)
      |> start_mining_task()

    {:noreply, new_state}
  end
end
