defmodule YAB.Transaction do
  @type t :: %__MODULE__{
          from_account: binary(),
          to_account: binary(),
          amount: integer(),
          signature: binary()
        }

  @enforce_keys [:from_account, :to_account, :amount, :signature]
  defstruct [:from_account, :to_account, :amount, :signature]

  @coinbase_amount 1729

  @spec coinbase(binary()) :: Transaction.t()
  def coinbase(to_account) do
    %__MODULE__{
      to_account: to_account,
      amount: @coinbase_amount,
      from_account: nil,
      signature: nil
    }
  end
end
