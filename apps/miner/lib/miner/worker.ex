defmodule Miner.Worker do
  use GenServer

  alias Miner.{
    Pool
  }

  alias YAB.{
    Chain,
    Block,
    KeyGenerator,
    POW,
    MerkleTree,
    Serializer
  }

  require Logger
  require Chain

  @private_key Application.get_env(:miner, __MODULE__)[:private_key]
  @public_key KeyGenerator.public_from_private(@private_key)
  @initial_delay 1000

  defmodule State do
    @type t :: %__MODULE__{
            accounts: Chain.account_balances(),
            blocks: [Block.t()]
          }

    @enforce_keys [:accounts, :blocks]
    defstruct [:accounts, :blocks]
  end

  def start_link() do
    state = %State{
      accounts: Chain.empty_accounts(),
      blocks: [Block.origin()]
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    schedule_mine()
    {:ok, state}
  end

  # TODO: Mine block in Task. Cancel if new block comes in from other peer
  def handle_info(:mine, %State{accounts: accounts, blocks: [latest_block | _] = blocks}) do
    Logger.debug("Pulling new transactions")
    transactions = Pool.get_transactions()

    Logger.debug("Got #{length(transactions)}")

    Logger.debug("Building candidate")

    {:ok, candidate, new_accounts} =
      Chain.build_candidate(latest_block, @public_key, accounts, transactions)

    Logger.debug("Mining block")
    block = %{candidate | header: POW.work(candidate.header)}

    Logger.debug("New block mined")

    new_state = %State{
      accounts: new_accounts,
      blocks: [block | blocks]
    }

    Logger.debug("Balance: #{Chain.get_account_balance(new_accounts, @public_key)}")
    schedule_mine()

    {:noreply, new_state}
  end

  defp schedule_mine() do
    Logger.debug("Scheduling mine")
    Process.send_after(self(), :mine, @initial_delay)
  end
end
