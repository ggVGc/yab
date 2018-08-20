defmodule YAB.Chain do
  alias YAB.{
    Block,
    Transaction,
    SerializingMerkleTree
  }

  @type accounts :: SerializingMerkleTree.t()
  @type account_error_reason :: :invalid_source_account | :low_balance

  @spec update_accounts(accounts(), [Transaction.t()]) ::
          {:ok, accounts()} | {:error, account_error_reason()}
  def update_accounts(initial_accounts, transactions) do
    result =
      Enum.reduce_while(transactions, initial_accounts, fn transaction, accum_accounts ->
        case apply_transaction_to_accounts(accum_accounts, transaction) do
          {:ok, new_accounts} ->
            {:cont, new_accounts}

          {:error, _} = error ->
            {:halt, error}
        end
      end)

    case result do
      {:error, _} = error ->
        error

      new_accounts ->
        {:ok, new_accounts}
    end
  end

  @spec apply_transaction_to_accounts(accounts(), Transaction.t()) ::
          {:ok, accounts()} | {:error, account_error_reason()}
  defp apply_transaction_to_accounts(
         accounts,
         %Transaction{
           amount: amount,
           from_account: from_account,
           to_account: to_account
         }
       ) do
    from_balance = SerializingMerkleTree.lookup(accounts, from_account)

    cond do
      is_nil(from_balance) ->
        {:error, :invalid_source_account}

      amount > from_balance ->
        {:error, :low_balance}

      true ->
        updated_accounts =
          accounts
          |> SerializingMerkleTree.put(from_account, from_balance - amount)
          |> SerializingMerkleTree.update(to_account, amount, &(&1 + amount))

        {:ok, updated_accounts}
    end
  end

  @spec add_block([Block.t()], Block.t()) :: [Block.t()]
  def add_block(blocks, %Block{} = new_block) do
    # TODO
    blocks
  end
end
