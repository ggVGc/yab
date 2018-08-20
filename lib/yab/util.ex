defmodule YAB.Util do
  defmacro empty_hash, do: <<0::256>>

  @spec generate_origin_header() :: YAB.BlockHeader.t()
  def generate_origin_header() do
    public_key =
      YAB.KeyGenerator.gen_private()
      |> YAB.KeyGenerator.public_from_private()

    candidate =
      YAB.Block.candidate(
        to_account: public_key,
        prev_block: empty_hash(),
        transactions: [],
        chain_root_hash: empty_hash()
      )

    YAB.Validator.proof_of_work(candidate.header)
  end
end
