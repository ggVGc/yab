defmodule ChainNode.Worker do
  use GenServer

  alias ChainNode.{
    Peer,
    TransactionPool
  }

  alias YAB.{
    Chain,
    Block,
    KeyGenerator,
    Serializer,
    MerkleTree
  }

  require Logger
  require Chain
  require Block

  @max_block_try_depth 2
  @default_peer Application.get_env(:chain_node, __MODULE__)[:default_peer]

  defmodule Listener do
    @type t :: module()
    @callback on_chain_joined() :: no_return()
    @callback on_new_block() :: no_return()
  end

  defmodule State do
    @type t :: %__MODULE__{
            accounts: Chain.account_balances(),
            blocks: [Block.t()],
            public_key: binary(),
            listener: Listener.t()
          }

    @enforce_keys [:accounts, :blocks, :public_key, :listener]
    defstruct [:accounts, :blocks, :public_key, :listener]
  end

  def start_link(opts) do
    listener = Keyword.fetch!(opts, :listener)

    public_key =
      case Keyword.get(opts, :public_key) do
        nil ->
          private_key = KeyGenerator.gen_private()
          KeyGenerator.public_from_private(private_key)

        key ->
          key
      end

    state = %State{
      accounts: Chain.empty_accounts(),
      blocks: [Block.origin()],
      public_key: public_key,
      listener: listener
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

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_account_balances() do
    GenServer.call(__MODULE__, :get_account_balances)
  end

  def set_account(new_public_key) when is_binary(new_public_key) do
    GenServer.call(__MODULE__, {:set_account, new_public_key})
  end

  def get_blocks() do
    GenServer.call(__MODULE__, :get_blocks)
  end

  def sync() do
    GenServer.cast(__MODULE__, :sync)
  end

  def add_block(%Block{} = new_block) do
    GenServer.cast(__MODULE__, {:add_block, new_block})
  end

  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_account_balances, _, %State{accounts: accounts} = state) do
    result =
      accounts
      |> MerkleTree.to_list()
      |> Enum.map(fn {key, value} ->
        {key, Serializer.unpack(value)}
      end)

    {:reply, result, state}
  end

  def handle_call({:set_account, new_public_key}, _, state) do
    {:reply, :ok, %State{state | public_key: new_public_key}}
  end

  def handle_call(:get_blocks, _, %State{blocks: blocks} = state) do
    {:reply, blocks, state}
  end

  # Quite ugly, but works for now
  def handle_info(:default_join, %State{listener: listener} = state) do
    {:ok, host} = :inet.gethostname()
    node_name = String.to_atom("#{@default_peer}@#{host}")

    if Node.self() == :nonode@nohost do
      Node.start(node_name, :shortnames)
    end

    cond do
      Node.self() == node_name ->
        Logger.info("Default peer started")
        listener.on_chain_joined()

      Node.ping(node_name) == :pang ->
        Logger.error(
          "Default peer not available.\n" <>
            "Start default peer with `iex --sname #{@default_peer} -S mix`,\n" <>
            "or manually announce to a known peer using Peer.announce_self/1."
        )

      true ->
        join_network(node_name)
        listener.on_chain_joined()
    end

    {:noreply, state}
  end

  defp reset_state(%State{} = state) do
    %State{
      state
      | blocks: [Block.origin()],
        accounts: Chain.empty_accounts()
    }
  end

  def handle_cast(:sync, %State{} = state) do
    Logger.debug("Syncing")

    blocks = Peer.get_blocks()
    Logger.debug("Received #{length(blocks)} blocks. Validating")

    # Not the most future proof implementation...
    [Block.origin() | rest_blocks] = Enum.reverse(blocks)

    synced_state =
      Enum.reduce(rest_blocks, reset_state(state), fn block, state ->
        {:ok, new_account_balances, new_blocks} = try_add_block(block, state)

        %State{
          state
          | blocks: new_blocks,
            accounts: new_account_balances
        }
      end)

    Logger.info("Blocks valid. Sync complete!")
    {:noreply, synced_state}
  end

  def handle_cast({:add_block, %Block{} = new_block}, %State{listener: listener} = state) do
    Logger.info("Adding new block")

    case try_add_block(new_block, state) do
      {:ok, new_account_balances, new_blocks} ->
        new_state = %State{
          state
          | accounts: new_account_balances,
            blocks: new_blocks
        }

        listener.on_new_block()
        Peer.broadcast_new_block(new_block)

        TransactionPool.remove_transactions(new_block.transactions)

        {:noreply, new_state}

      {:error, :block_already_added} ->
        {:noreply, state}

      {:error, reason} ->
        Logger.info("Received invalid(#{reason}) block: #{inspect(new_block.header)}")
        {:noreply, state}
    end
  end

  defp try_add_block(new_block, state), do: try_add_block(0, new_block, state)

  # We could check further down, but it's a very unexpected case, and if the chain
  # has grown much longer, the new block will be rejected anyway
  defp try_add_block(_, new_block, %State{blocks: [latest_block | _]})
       when new_block == latest_block,
       do: {:error, :block_already_added}

  defp try_add_block(
         tries,
         %Block{} = new_block,
         %State{accounts: accounts, blocks: [latest_block | rest_blocks] = blocks} = state
       ) do
    case Chain.validate_block(latest_block, accounts, new_block) do
      {:ok, ^new_block, []} ->
        [coinbase_transaction | transactions] = new_block.transactions

        {updated_accounts, _, []} =
          accounts
          |> Chain.apply_coinbase_transaction(coinbase_transaction)
          |> Chain.apply_transactions(transactions)

        {:ok, updated_accounts, [new_block | blocks]}

      {:ok, _, [_]} ->
        {:error, :new_block_contains_invalid_transactions}

      {:error, _} = error ->
        if tries >= @max_block_try_depth or rest_blocks == [] do
          error
        else
          try_add_block(tries + 1, new_block, %State{state | blocks: rest_blocks})
        end
    end
  end
end
