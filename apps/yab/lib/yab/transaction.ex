defmodule YAB.Transaction do
  @type t :: %__MODULE__{
          from_account: binary(),
          to_account: binary(),
          amount: integer()
        }

  @enforce_keys [:from_account, :to_account, :amount]
  defstruct [:from_account, :to_account, :amount]
end
