defmodule YAB.Transaction do
  import YAB.Util, only: [empty_hash: 0]

  @type t :: %__MODULE__{
          from_account: binary(),
          to_account: binary(),
          amount: integer(),
          signature: binary()
        }

  @enforce_keys [:from_account, :to_account, :amount, :signature]
  defstruct [:from_account, :to_account, :amount, :signature]

  @coinbase_amount Application.get_env(:yab, __MODULE__)[:coinbase_amount]

  @spec coinbase(binary()) :: __MODULE__.t()
  def coinbase(to_account) do
    %__MODULE__{
      to_account: to_account,
      amount: @coinbase_amount,
      from_account: empty_hash(),
      signature: empty_hash()
    }
  end
end
