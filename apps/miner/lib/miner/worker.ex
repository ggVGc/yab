defmodule Miner.Worker do
  use GenServer

  alias Miner.{
    Pool
  }

  alias YAB.{
    Chain,
    Block,
    KeyGenerator,
    POW
  }

  require Logger
  require Chain

  @private_key Application.get_env(:miner, __MODULE__)[:private_key]
  @public_key KeyGenerator.public_from_private(@private_key)
  @initial_delay 1000

  defmodule State do
    @type t :: %__MODULE__{
            accounts: Chain.account_balances(),
            blocks: [Block.t()],
            active_mining_task: Task.t() | nil
          }

    @enforce_keys [:accounts, :blocks, :active_mining_task]
    defstruct [:accounts, :blocks, :active_mining_task]
  end

  def start_link() do
    state = %State{
      accounts: Chain.empty_accounts(),
      blocks: [Block.origin()],
      active_mining_task: nil
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    schedule_mining()
    {:ok, state}
  end

  def handle_info(:mine, %State{active_mining_task: active_mining_task})
      when not is_nil(active_mining_task),
      do: raise("mining task already active")

  def handle_info(
        :mine,
        %State{
          accounts: accounts,
          blocks: [latest_block | _] = blocks
        } = old_state
      ) do
    Logger.debug("Pulling new transactions")
    transactions = Pool.get_transactions()

    Logger.debug("Got #{length(transactions)}")

    Logger.debug("Building candidate")

    # TODO: Purge invalid transactions
    {:ok, candidate, new_accounts} =
      Chain.build_candidate(latest_block, @public_key, accounts, transactions)

    task =
      Task.Supervisor.async(Miner.TaskSupervisor, fn ->
        mine(candidate, new_accounts, blocks)
      end)

    new_state = %{
      old_state
      | active_mining_task: task
    }

    {:noreply, new_state}
  end

  defp mine(candidate, new_accounts, blocks) do
    Logger.debug("Mining block")
    mined_block = %{candidate | header: POW.work(candidate.header)}

    Logger.debug("New block mined")

    # Peer.broadcast_new_block(mined_block)

    add_mined_block(mined_block, new_accounts)
  end

  def add_mined_block(%Block{} = mined_block, new_accounts) do
    GenServer.cast(__MODULE__, {:add_mined_block, mined_block, new_accounts})
  end

  def handle_cast({:add_mined_block, mined_block, new_accounts}, %State{
        blocks: blocks,
        active_mining_task: active_mining_task
      }) do
    # Make sure task actually finished
    _ = Task.await(active_mining_task)

    new_state = %State{
      accounts: new_accounts,
      blocks: [mined_block | blocks],
      active_mining_task: nil
    }

    Logger.debug("Balance: #{Chain.get_account_balance(new_accounts, @public_key)}")
    schedule_mining()

    {:noreply, new_state}
  end

  defp schedule_mining() do
    Logger.debug("Scheduling mine")
    Process.send_after(__MODULE__, :mine, @initial_delay)
  end
end
