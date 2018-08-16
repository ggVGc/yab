defmodule YAB.Block do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Transaction,
    BlockHeader,
    Validator
  }

  @type t :: %__MODULE__{
          header: BlockHeader.t(),
          transactions: [Transaction.t()]
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
    to_account = Keyword.fetch!(args, :to_account)
    prev_block = Keyword.fetch!(args, :prev_block)
    transactions = Keyword.fetch!(args, :transactions)
    chain_root_hash = Keyword.fetch!(args, :chain_root_hash)

    transactions_with_coinbase = [Transaction.coinbase(to_account) | transactions]

    %__MODULE__{
      transactions: transactions_with_coinbase,
      header: %BlockHeader{
        previous_hash: prev_block,
        difficulty_target: @difficulty,
        nonce: 0,
        chain_root_hash: chain_root_hash,
        transactions_root_hash: Validator.hash_transactions(transactions_with_coinbase)
      }
    }
  end

  @spec origin() :: __MODULE__.t()
  def origin() do
    %__MODULE__{
      transactions: [],
      header: @origin_header
    }
  end
end
