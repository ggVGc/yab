defmodule YAB.SignedTransaction do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Transaction,
    Serializer,
    Signer
  }

  @type t :: %__MODULE__{
          transaction: Transaction.t(),
          signature: binary()
        }

  @enforce_keys [:transaction, :signature]
  defstruct [:transaction, :signature]

  @spec coinbase(binary()) :: __MODULE__.t()
  def coinbase(to_account) do
    %__MODULE__{
      transaction: Transaction.coinbase(to_account),
      signature: empty_hash()
    }
  end

  @spec signature_valid?(__MODULE__.t()) :: boolean()
  def signature_valid?(%__MODULE__{
        signature: signature,
        transaction: %Transaction{from_account: from_account} = transaction
      }) do
    Signer.verify(Serializer.pack(transaction), signature, from_account)
  end
end
