defmodule YAB.Block do
  alias YAB.{
    SignedTransaction,
    BlockHeader,
    Chain
  }

  @type t :: %__MODULE__{
          header: BlockHeader.t(),
          transactions: [SignedTransaction.t()]
        }

  @enforce_keys [:header, :transactions]
  defstruct [:header, :transactions]

  @difficulty Application.get_env(:yab, __MODULE__)[:difficulty]
  @origin_header struct(
                   BlockHeader,
                   Application.get_env(:yab, __MODULE__)[:origin_header_content]
                 )

  defmacro difficulty(), do: @difficulty

  @spec candidate(Keyword.t()) :: __MODULE__.t()
  def candidate(args) do
    miner_account = Keyword.fetch!(args, :miner_account)
    prev_block_hash = Keyword.fetch!(args, :prev_block_hash)
    transactions = Keyword.fetch!(args, :transactions)
    chain_root_hash = Keyword.fetch!(args, :chain_root_hash)

    transactions_with_coinbase = [SignedTransaction.coinbase(miner_account) | transactions]

    %__MODULE__{
      transactions: transactions_with_coinbase,
      header: %BlockHeader{
        previous_hash: prev_block_hash,
        difficulty_target: @difficulty,
        nonce: 0,
        chain_root_hash: chain_root_hash,
        transactions_root_hash: Chain.hash_transactions(transactions_with_coinbase)
      }
    }
  end

  def set_transactions(%__MODULE__{header: header} = block, transactions) do
    %__MODULE__{
      transactions: transactions,
      header: %BlockHeader{
        header
        | transactions_root_hash: Chain.hash_transactions(transactions)
      }
    }
  end

  defmacro origin() do
    origin_block = Macro.escape(%__MODULE__{transactions: [], header: @origin_header})

    quote do
      unquote(origin_block)
    end
  end
end
