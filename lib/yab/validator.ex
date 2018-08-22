defmodule YAB.Validator do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Serializer,
    SignedTransaction,
    BlockHeader,
    Hasher,
    Block,
    MerkleTree
  }

  require Block

  @spec proof_of_work(BlockHeader.t()) :: BlockHeader.t()
  def proof_of_work(%BlockHeader{nonce: nonce} = header) do
    hash = Hasher.hash(Serializer.pack(header))

    if matches_difficulty_target?(hash) do
      header
    else
      proof_of_work(%{header | nonce: nonce + 1})
    end
  end

  @target_leading_zeroes <<0::size(Block.difficulty())-unit(8)>>

  @spec matches_difficulty_target?(binary()) :: boolean()
  defp matches_difficulty_target?(hash) do
    <<leading_zeroes::binary-size(Block.difficulty()), _::binary>> = hash
    leading_zeroes == @target_leading_zeroes
  end

  @spec hash_transactions([SignedTransaction.t()]) :: binary()
  def hash_transactions([]) do
    empty_hash()
  end

  def hash_transactions(transactions) do
    build_transactions_tree(transactions)
    |> MerkleTree.root_hash()
  end

  defp build_transactions_tree(transactions) do
    transactions
    |> Enum.reduce(MerkleTree.empty(), fn transaction, accum_tree ->
      packed_transaction = Serializer.pack(transaction)
      hash = Hasher.hash(packed_transaction)

      MerkleTree.put(accum_tree, hash, packed_transaction)
    end)
  end
end
