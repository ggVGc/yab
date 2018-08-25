defmodule YAB.ChainTest do
  import YAB.Serializer, only: [pack: 1, unpack: 1]

  use YAB.TestCase

  alias YAB.{
    MerkleTree,
    Transaction,
    Block,
    Chain,
    SignedTransaction
  }

  require Block

  test "Candidate with no transactions" do
    {:ok, %Block{}, []} =
      Chain.build_candidate(
        Block.origin(),
        @miner_account,
        MerkleTree.empty(),
        []
      )
  end

  defp candidate_with_transaction(
         accounts \\ MerkleTree.empty(),
         %SignedTransaction{} = transaction
       ) do
    Chain.build_candidate(
      Block.origin(),
      @miner_account,
      accounts,
      [transaction]
    )
  end

  test "Reject invalid source account" do
    from_keys = new_keys()

    transaction =
      %Transaction{
        from_account: from_keys.public,
        to_account: new_keys().public,
        amount: 1
      }
      |> SignedTransaction.sign(from_keys.private)

    {:ok, _, [invalid_transaction]} = candidate_with_transaction(transaction)
    assert elem(invalid_transaction, 1) == :invalid_source_account
  end

  test "Transfer to new account" do
    from_keys = new_keys()
    to_account = new_keys().public
    initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

    transaction =
      %Transaction{
        from_account: from_keys.public,
        to_account: to_account,
        amount: 1
      }
      |> SignedTransaction.sign(from_keys.private)

    {:ok, candidate, []} = candidate_with_transaction(initial_accounts, transaction)
    {new_accounts, _, _} = Chain.apply_transactions(initial_accounts, candidate.transactions)

    assert unpack(MerkleTree.lookup(new_accounts, to_account)) == 1
  end

  test "Reject insufficient funds" do
    from_keys = new_keys()
    initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

    transaction =
      %Transaction{
        from_account: from_keys.public,
        to_account: new_keys().public,
        amount: 2
      }
      |> SignedTransaction.sign(from_keys.private)

    {:ok, _, [invalid_transaction]} = candidate_with_transaction(initial_accounts, transaction)
    assert elem(invalid_transaction, 1) == :low_balance
  end

  test "Transfer to existing account", %{} do
    from_keys = new_keys()
    to_account = new_keys().public

    initial_accounts =
      MerkleTree.empty()
      |> MerkleTree.put(from_keys.public, pack(2))
      |> MerkleTree.put(to_account, pack(3))

    transaction =
      %Transaction{
        from_account: from_keys.public,
        to_account: to_account,
        amount: 2
      }
      |> SignedTransaction.sign(from_keys.private)

    {:ok, candidate, []} = candidate_with_transaction(initial_accounts, transaction)
    {new_accounts, _, _} = Chain.apply_transactions(initial_accounts, candidate.transactions)

    assert unpack(MerkleTree.lookup(new_accounts, to_account)) == 5
  end

  # @coinbase_amount Application.get_env(:yab, YAB.SignedTransaction)[:coinbase_amount]

  # test "Miner receives coinbase" do
  #   from_keys = new_keys()
  #   initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

  #   transaction =
  #     %Transaction{
  #       from_account: from_keys.public,
  #       to_account: new_keys().public,
  #       amount: 1
  #     }
  #     |> SignedTransaction.sign(from_keys.private)

  #   {:ok, candidate, []} = candidate_with_transaction(initial_accounts, transaction)
  #   {new_accounts, _, _} = Chain.apply_transactions(initial_accounts, candidate.transactions)

  #   assert unpack(MerkleTree.lookup(new_accounts, @miner_account)) == @coinbase_amount
  # end

  # test "Reject invalid coinbase transaction", %{} do
  #   assert "TODO" == ""
  # end
end
