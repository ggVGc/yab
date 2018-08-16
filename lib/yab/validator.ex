defmodule YAB.Validator do
  import YAB.Util, only: [empty_hash: 0]

  alias YAB.{
    Serializer,
    Transaction,
    BlockHeader,
    Hasher,
    Block
  }

  require Block

  @spec proof_of_work(BlockHeader.t()) :: BlockHeader.t()
  def proof_of_work(%BlockHeader{nonce: nonce} = header) do
    hash = Hasher.hash(Serializer.pack(header))

    if matches_difficulty_target?(hash) do
      header
    else
      proof_of_work(%{
        header
        | nonce: header.nonce + 1
      })
    end
  end

  @target_leading_zeroes <<0::size(Block.difficulty())-unit(8)>>

  @spec matches_difficulty_target?(binary()) :: boolean()
  defp matches_difficulty_target?(hash) do
    <<leading_zeroes::binary-size(Block.difficulty()), _::binary>> = hash
    leading_zeroes == @target_leading_zeroes
  end

  @spec hash_transactions([YAB.Transaction.t()]) :: binary()
  def hash_transactions([]) do
    empty_hash()
  end

  def hash_transactions(transactions) do
    build_transactions_tree(transactions)
    |> :gb_merkle_trees.root_hash()
  end

  def build_transactions_tree(transactions) do
    transactions
    |> Enum.reduce(:gb_merkle_trees.empty(), fn transaction, accum_tree ->
      packed_transaction = Serializer.pack(transaction)
      hash = Hasher.hash(packed_transaction)

      :gb_merkle_trees.enter(hash, packed_transaction, accum_tree)
    end)
  end

  @spec validate_transaction(Transaction.t()) :: boolean()
  defp validate_transaction(%Transaction{} = transaction) do
    # TODO
    false
  end
end
