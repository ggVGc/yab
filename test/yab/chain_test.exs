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

  defp execute_transaction(accounts \\ MerkleTree.empty(), %SignedTransaction{} = transaction) do
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
      |> Transaction.sign(from_keys.private)

    assert execute_transaction(transaction) == {:error, :invalid_source_account}
  end

  test "Transfer to new account" do
    from_keys = new_keys()
    to_account = new_keys().public
    initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

    {:ok, _, new_accounts} =
      execute_transaction(
        initial_accounts,
        %Transaction{
          from_account: from_keys.public,
          to_account: to_account,
          amount: 1
        }
        |> Transaction.sign(from_keys.private)
      )

    assert unpack(MerkleTree.lookup(new_accounts, to_account)) == 1
  end

  test "Reject insufficient funds" do
    from_keys = new_keys()
    initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

    result =
      execute_transaction(
        initial_accounts,
        %Transaction{
          from_account: from_keys.public,
          to_account: new_keys().public,
          amount: 2
        }
        |> Transaction.sign(from_keys.private)
      )

    assert result == {:error, :low_balance}
  end

  test "Transfer to existing account", %{} do
    from_keys = new_keys()
    to_account = new_keys().public

    initial_accounts =
      MerkleTree.empty()
      |> MerkleTree.put(from_keys.public, pack(2))
      |> MerkleTree.put(to_account, pack(3))

    {:ok, _, new_accounts} =
      execute_transaction(
        initial_accounts,
        %Transaction{
          from_account: from_keys.public,
          to_account: to_account,
          amount: 2
        }
        |> Transaction.sign(from_keys.private)
      )

    assert unpack(MerkleTree.lookup(new_accounts, to_account)) == 5
  end

  @coinbase_amount Application.get_env(:yab, YAB.Transaction)[:coinbase_amount]

  test "Miner receives coinbase" do
    from_keys = new_keys()
    initial_accounts = MerkleTree.put(MerkleTree.empty(), from_keys.public, pack(1))

    {:ok, _, new_accounts} =
      execute_transaction(
        initial_accounts,
        %Transaction{
          from_account: from_keys.public,
          to_account: new_keys().public,
          amount: 1
        }
        |> Transaction.sign(from_keys.private)
      )

    assert unpack(MerkleTree.lookup(new_accounts, @miner_account)) == @coinbase_amount
  end

  test "Reject invalid coinbase transaction", %{} do
    assert "TODO" == ""
  end
end
