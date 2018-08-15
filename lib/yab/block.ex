defmodule YAB.Block do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Transaction,
    BlockHeader
  }

  @type t :: %__MODULE__{
          header: BlockHeader.t(),
          transactions: [Transaction.t()]
        }

  @enforce_keys [:header, :transactions]
  defstruct [:header, :transactions]

  @difficulty Application.get_env(:yab, __MODULE__)[:difficulty]
  @genesis_header Application.get_env(:yab, __MODULE__)[:genesis_header]

  @spec candidate(binary(), [Transaction.t()]) :: Block.t()
  def candidate(to_account, transactions) do
    %__MODULE__{
      transactions: [Transaction.coinbase(to_account) | transactions],
      header: %BlockHeader{
        previous_hash: empty_hash(),
        difficulty_target: @difficulty,
        nonce: 0
        # chain_root_hash: ,
        # transactions_root_hash: 
      }
    }
  end

  @spec genesis() :: Block.t()
  def genesis() do
    %__MODULE__{
      transactions: [],
      header: @genesis_header
    }
  end
end
