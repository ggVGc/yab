defmodule YAB.BlockHeader do
  @type t :: %__MODULE__{
          previous_hash: binary(),
          difficulty_target: integer(),
          nonce: integer(),
          chain_root_hash: binary(),
          transactions_root_hash: binary()
        }

  @enforce_keys [
    :previous_hash,
    :difficulty_target,
    :nonce,
    :chain_root_hash,
    :transactions_root_hash
  ]
  defstruct [
    :previous_hash,
    :difficulty_target,
    :nonce,
    :chain_root_hash,
    :transactions_root_hash
  ]
end
