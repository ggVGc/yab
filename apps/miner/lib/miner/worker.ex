defmodule Miner.Worker do
  use GenServer

  alias Miner.{
    Pool,
    Peer
  }

  alias YAB.{
    Chain,
    Block,
    KeyGenerator,
    POW
  }

  require Logger
  require Chain

  @max_block_try_depth 2
  @initial_delay 1000
  @default_root_node_name Application.get_env(:miner, __MODULE__)[:default_root_node_name]

  defmodule State do
    @type t :: %__MODULE__{
            accounts: Chain.account_balances(),
            blocks: [Block.t()],
            active_mining_task: Task.t() | nil,
            public_key: binary()
          }

    @enforce_keys [:accounts, :blocks, :active_mining_task, :public_key]
    defstruct [:accounts, :blocks, :active_mining_task, :public_key]
  end

  def start_link() do
    private_key = KeyGenerator.gen_private()

    state = %State{
      accounts: Chain.empty_accounts(),
      blocks: [Block.origin()],
      active_mining_task: nil,
      public_key: KeyGenerator.public_from_private(private_key)
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    Process.send_after(__MODULE__, :default_join, 500)
    {:ok, state}
  end

  def join_network(any_active_node_name) do
    Peer.announce_self(any_active_node_name)
    sync()
  end

  def status() do
    GenServer.cast(__MODULE__, :status)
  end

  def set_account(new_public_key) when is_binary(new_public_key) do
    GenServer.call(__MODULE__, {:set_account, new_public_key})
  end

  def get_blocks() do
    GenServer.call(__MODULE__, :get_blocks)
  end

  def add_mined_block(%Block{} = mined_block, new_accounts) do
    GenServer.cast(__MODULE__, {:add_mined_block, mined_block, new_accounts})
  end

  def add_external_block(%Block{} = new_block) do
    GenServer.cast(__MODULE__, {:add_external_block, new_block})
  end

  def sync() do
    GenServer.cast(__MODULE__, :sync)
  end

  def handle_call({:set_account, new_public_key}, _, state) do
    {:reply, :ok, %State{state | public_key: new_public_key}}
  end

  def handle_call(:get_blocks, _, %State{blocks: blocks} = state) do
    {:reply, blocks, state}
  end

  def handle_info(:default_join, state) do
    # Bit ugly, but works for now
    {:ok, host} = :inet.gethostname()
    node_name = String.to_atom("#{@default_root_node_name}@#{host}")

    if Node.self() == node_name or Node.ping(node_name) == :pang do
      schedule_mining()
    else
      join_network(node_name)
    end

    {:noreply, state}
  end

  def handle_info(:mine, %State{active_mining_task: active_mining_task})
      when not is_nil(active_mining_task),
      do: raise("mining task already active")

  def handle_info(
        :mine,
        %State{
          accounts: accounts,
          blocks: [latest_block | _],
          public_key: public_key
        } = old_state
      ) do
    Logger.debug("Pulling new transactions")

    transactions = Pool.get_transactions()

    Logger.debug("Got #{length(transactions)}")
    Logger.debug("Building candidate")

    # TODO: Purge invalid transactions
    {:ok, candidate, new_accounts} =
      Chain.build_candidate(latest_block, public_key, accounts, transactions)

    task =
      Task.Supervisor.async(Miner.TaskSupervisor, fn ->
        mine(candidate, new_accounts)
      end)

    new_state = %{old_state | active_mining_task: task}

    {:noreply, new_state}
  end

  defp mine(candidate, new_accounts) do
    Logger.info("Mining block")

    mined_block = %{candidate | header: POW.work(candidate.header)}

    Logger.debug("New block mined")

    Peer.broadcast_new_block(mined_block)
    add_mined_block(mined_block, new_accounts)
  end

  def handle_cast(:status, %State{accounts: accounts, public_key: public_key} = state) do
    Chain.get_account_balance(accounts, public_key)
    |> IO.inspect(label: "balance")

    public_key |> IO.inspect(label: "account", limit: :infinity)

    {:noreply, state}
  end

  def handle_cast(:sync, %State{} = state) do
    Logger.debug("Syncing")

    kill_mining_task_if_active(state)

    origin_block = Block.origin()

    # Not the most future proof implementation...
    [^origin_block | blocks] = Enum.reverse(Peer.get_blocks())

    Logger.debug("Received #{length(blocks) + 1} blocks. Validating")

    {accounts, _} =
      Enum.reduce(blocks, {Chain.empty_accounts(), origin_block}, fn block,
                                                                     {accounts, latest_block} ->
        {:ok, accounts} = Chain.validate_block(latest_block, accounts, block)
        {accounts, block}
      end)

    Logger.info("Blocks valid. Sync complete!")

    schedule_mining()

    {:noreply,
     %State{
       state
       | blocks: Enum.reverse([origin_block | blocks]),
         accounts: accounts,
         active_mining_task: nil,
         public_key: state.public_key
     }}
  end

  def handle_cast(
        {:add_mined_block, mined_block, new_accounts},
        %State{
          blocks: blocks,
          active_mining_task: active_mining_task,
          public_key: public_key
        } = old_state
      ) do
    # Make sure task actually finished
    _ = Task.await(active_mining_task)

    new_state = %State{
      old_state
      | accounts: new_accounts,
        blocks: [mined_block | blocks],
        active_mining_task: nil
    }

    Logger.debug("Balance: #{Chain.get_account_balance(new_accounts, public_key)}")

    schedule_mining()

    {:noreply, new_state}
  end

  def handle_cast({:add_external_block, %Block{} = new_block}, %State{} = state) do
    Logger.info("Received external block")

    case try_add_block(new_block, state) do
      {:ok, new_account_balances, new_blocks} ->
        kill_mining_task_if_active(state)

        new_state = %State{
          state
          | accounts: new_account_balances,
            blocks: new_blocks,
            active_mining_task: nil
        }

        schedule_mining()
        {:noreply, new_state}

      {:error, reason} ->
        Logger.info("Received invalid(#{reason}) block: #{inspect(new_block.header)}")
        {:noreply, state}
    end
  end

  defp kill_mining_task_if_active(%State{active_mining_task: nil}), do: false

  defp kill_mining_task_if_active(%State{active_mining_task: active_mining_task}) do
    Logger.info("Killing active mining task")
    Task.shutdown(active_mining_task, :brutal_kill)
  end

  defp try_add_block(new_block, state), do: try_add_block(0, new_block, state)

  defp try_add_block(
         tries,
         %Block{} = new_block,
         %State{accounts: accounts, blocks: [latest_block | rest_blocks] = blocks} = state
       ) do
    case Chain.validate_block(latest_block, accounts, new_block) do
      {:ok, new_account_balances} ->
        {:ok, new_account_balances, [new_block | blocks]}

      {:error, _} = error ->
        if tries >= @max_block_try_depth or rest_blocks == [] do
          error
        else
          try_add_block(tries + 1, new_block, %State{state | blocks: rest_blocks})
        end
    end
  end

  defp schedule_mining() do
    Logger.debug("Scheduling mining")
    Process.send_after(__MODULE__, :mine, @initial_delay)
  end
end
