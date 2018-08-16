use Mix.Config

# TODO: private_key should be part of node, not of blockchain lib

difficulty = 2

config :yab, YAB.Signer,
  private_key: <<188, 126, 81, 175, 35, 201, 159, 7, 242, 8, 199, 250, 40, 230, 72, 230>>

config :yab, YAB.Transaction, coinbase_amount: 1729

config :yab, YAB.Block,
  difficulty: difficulty,
  origin_header_content: %{
    chain_root_hash: <<0::256>>,
    difficulty_target: 2,
    nonce: 16100,
    previous_hash: <<0::256>>,
    transactions_root_hash:
      <<136, 28, 17, 144, 203, 238, 194, 195, 79, 191, 37, 85, 146, 236, 117, 99, 20, 171, 141,
        195, 8, 216, 94, 164, 221, 11, 219, 252, 27, 76, 241, 156>>
  }
