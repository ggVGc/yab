defmodule YAB.Transaction do
  import YAB.Util, only: [empty_hash: 0]

  @type t :: %__MODULE__{
          from_account: binary(),
          to_account: binary(),
          amount: integer()
        }

  @enforce_keys [:from_account, :to_account, :amount]
  defstruct [:from_account, :to_account, :amount]
end
