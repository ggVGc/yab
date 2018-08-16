defmodule YAB.Util do
  @key_entropy_bytes 16

  defmacro empty_hash, do: <<0::256>>

  @spec generate_origin_header() :: YAB.BlockHeader.t()
  def generate_origin_header() do
    private_key = :crypto.strong_rand_bytes(@key_entropy_bytes)
    public_key = :crypto.generate_key(:ecdh, :secp256k1, private_key)

    YAB.Block.candidate(
      to_account: public_key,
      prev_block: empty_hash(),
      transactions: [],
      chain_root_hash: empty_hash()
    ).header
    |> YAB.Validator.proof_of_work()
  end
end
