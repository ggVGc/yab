defmodule Mix.Tasks.GenOriginHeader do
  use Mix.Task

  import YAB.Util, only: [empty_hash: 0]

  def run(_) do
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
    |> IO.inspect()
  end
end
