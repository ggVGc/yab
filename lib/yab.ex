defmodule YAB do
  alias YAB.{
    Serializer,
    Transaction,
    Block
  }

  @spec hash_transactions([Transaction.t()]) :: binary()
  def hash_transactions([]) do
    <<0::256>>
  end

  def hash_transactions(transactions) do
    build_transactions_tree(transactions)
    |> :gb_merkle_trees.root_hash()
  end

  defp build_transactions_tree(transactions) do
    transactions
    |> Enum.reduce(:gb_merkle_trees.empty(), fn transaction, accum_tree ->
      packed_transaction = Serializer.pack(transaction)
      hash = :crypto.hash(:sha256, packed_transaction)

      :gb_merkle_trees.enter(hash, packed_transaction, accum_tree)
    end)
  end

  def proof_of_work_block(%Block{} = block), do: proof_of_work_block(block, 0)

  def proof_of_work_block(%Block{} = block, nonce) do
    # TODO
  end
end
