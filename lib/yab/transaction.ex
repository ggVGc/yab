defmodule YAB.Transaction do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Signer,
    Serializer
  }

  @type t :: %__MODULE__{
          from_account: binary(),
          to_account: binary(),
          amount: integer()
        }

  @enforce_keys [:from_account, :to_account, :amount]
  defstruct [:from_account, :to_account, :amount]

  @coinbase_amount Application.get_env(:yab, __MODULE__)[:coinbase_amount]

  @spec coinbase(binary()) :: __MODULE__.t()
  def coinbase(to_account) do
    %__MODULE__{
      to_account: to_account,
      amount: @coinbase_amount,
      from_account: empty_hash()
    }
  end

  @spec sign(__MODULE__.t(), binary()) :: YAB.SignedTransaction.t()
  def sign(%__MODULE__{} = transaction, private_key) do
    %YAB.SignedTransaction{
      transaction: transaction,
      signature:
        Serializer.pack(transaction)
        |> Signer.sign(private_key)
    }
  end
end
