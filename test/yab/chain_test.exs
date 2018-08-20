defmodule YAB.ChainTest do
  use ExUnit.Case

  alias YAB.{
    MerkleTree,
    Transaction,
    KeyGenerator,
    Chain
  }

  describe "update_accounts/2" do
    test "Reject invalid source account" do
      transaction = %Transaction{
        from_account: new_pub_key(),
        to_account: new_pub_key(),
        amount: 1,
        signature: nil
      }

      assert Chain.update_accounts(MerkleTree.empty(), [transaction]) ==
               {:error, :invalid_source_account}
    end

    test "Transfer to new account" do
      transaction = %Transaction{
        from_account: new_pub_key(),
        to_account: new_pub_key(),
        amount: 1,
        signature: nil
      }

      accounts =
        MerkleTree.empty()
        |> MerkleTree.put(transaction.from_account, 1)

      {:ok, new_accounts} = Chain.update_accounts(accounts, [transaction])
      assert MerkleTree.lookup(new_accounts, transaction.to_account) == 1
    end

    test "Reject insufficient funds" do
      transaction = %Transaction{
        from_account: new_pub_key(),
        to_account: new_pub_key(),
        amount: 2,
        signature: nil
      }

      accounts =
        MerkleTree.empty()
        |> MerkleTree.put(transaction.from_account, 1)

      assert Chain.update_accounts(accounts, [transaction]) == {:error, :low_balance}
    end

    test "Transfer to existing account", %{} do
      transaction = %Transaction{
        from_account: new_pub_key(),
        to_account: new_pub_key(),
        amount: 2,
        signature: nil
      }

      accounts =
        MerkleTree.empty()
        |> MerkleTree.put(transaction.from_account, 2)
        |> MerkleTree.put(transaction.to_account, 3)

      {:ok, new_accounts} = Chain.update_accounts(accounts, [transaction])
      assert MerkleTree.lookup(new_accounts, transaction.to_account) == 5
    end
  end

  defp new_pub_key() do
    KeyGenerator.gen_private()
    |> KeyGenerator.public_from_private()
  end
end
