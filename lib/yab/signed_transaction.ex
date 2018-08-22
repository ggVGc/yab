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

  @coinbase_amount Application.get_env(:yab, __MODULE__)[:coinbase_amount]

  @spec coinbase(binary()) :: __MODULE__.t()
  def coinbase(to_account) do
    %__MODULE__{
      transaction: %Transaction{
        to_account: to_account,
        amount: @coinbase_amount,
        from_account: empty_hash()
      },
      signature: empty_hash()
    }
  end

  @spec sign(Transaction.t(), binary()) :: __MODULE__.t()
  def sign(%Transaction{} = transaction, private_key) do
    %__MODULE__{
      transaction: transaction,
      signature:
        Serializer.pack(transaction)
        |> Signer.sign(private_key)
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
