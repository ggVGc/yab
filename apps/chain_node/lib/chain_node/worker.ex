defmodule ChainNode.Worker do
  use GenServer

  alias ChainNode.{
    Peer
  }

  alias YAB.{
    Chain,
    Block,
    KeyGenerator
  }

  require Logger
  require Chain

  @max_block_try_depth 2
  @default_root_node_name Application.get_env(:chain_node, __MODULE__)[:default_root_node_name]

  defmodule Listener do
    @type t :: module()
    @callback on_chain_joined() :: no_return()
    @callback on_new_external_block() :: no_return()
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

  def start_link(listener) do
    private_key = KeyGenerator.gen_private()

    state = %State{
      accounts: Chain.empty_accounts(),
      blocks: [Block.origin()],
      public_key: KeyGenerator.public_from_private(private_key),
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

  def status() do
    GenServer.cast(__MODULE__, :status)
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

  def add_external_block(%Block{} = new_block) do
    GenServer.cast(__MODULE__, {:add_external_block, new_block})
  end

  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call({:set_account, new_public_key}, _, state) do
    {:reply, :ok, %State{state | public_key: new_public_key}}
  end

  def handle_call(:get_blocks, _, %State{blocks: blocks} = state) do
    {:reply, blocks, state}
  end

  def handle_call(
        {:add_mined_block, mined_block, updated_accounts},
        _,
        %State{blocks: blocks} = state
      ) do
    new_state = %State{
      state
      | accounts: updated_accounts,
        blocks: [mined_block | blocks]
    }

    Peer.broadcast_new_block(mined_block)

    {:reply, :ok, new_state}
  end

  # Quite ugly, but works for now
  def handle_info(:default_join, %State{listener: listener} = state) do
    {:ok, host} = :inet.gethostname()
    node_name = String.to_atom("#{@default_root_node_name}@#{host}")

    if Node.self() == :nonode@nohost do
      Node.start(node_name, :shortnames)
    end

    cond do
      Node.self() == node_name ->
        Logger.info("Default root node started")
        listener.on_chain_joined()

      Node.ping(node_name) == :pang ->
        Logger.error("Default root node not available. Try joining network manually.")

      true ->
        join_network(node_name)
        listener.on_chain_joined()
    end

    {:noreply, state}
  end

  def handle_cast(:status, %State{accounts: accounts, public_key: public_key} = state) do
    Chain.get_account_balance(accounts, public_key)
    |> IO.inspect(label: "balance")

    public_key |> IO.inspect(label: "account", limit: :infinity)

    {:noreply, state}
  end

  def handle_cast(:sync, %State{} = state) do
    Logger.debug("Syncing")

    origin_block = Block.origin()

    blocks = Peer.get_blocks()

    # Not the most future proof implementation...
    [^origin_block | rest_blocks] = Enum.reverse(blocks)

    Logger.debug("Received #{length(blocks) + 1} blocks. Validating")

    {accounts, _} =
      Enum.reduce(rest_blocks, {Chain.empty_accounts(), origin_block}, fn block,
                                                                          {accounts, latest_block} ->
        {:ok, accounts} = Chain.validate_block(latest_block, accounts, block)
        {accounts, block}
      end)

    Logger.info("Blocks valid. Sync complete!")

    {:noreply,
     %State{
       state
       | blocks: blocks,
         accounts: accounts,
         public_key: state.public_key
     }}
  end

  def handle_cast({:add_external_block, %Block{} = new_block}, %State{listener: listener} = state) do
    Logger.info("Received external block")

    case try_add_block(new_block, state) do
      {:ok, new_account_balances, new_blocks} ->
        new_state = %State{
          state
          | accounts: new_account_balances,
            blocks: new_blocks
        }

        listener.on_new_external_block()
        {:noreply, new_state}

      {:error, reason} ->
        Logger.info("Received invalid(#{reason}) block: #{inspect(new_block.header)}")
        {:noreply, state}
    end
  end

  def add_mined_block(mined_block, updated_accounts) do
    GenServer.call(__MODULE__, {:add_mined_block, mined_block, updated_accounts})
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
end
