defmodule YAB.Chain do
  import YAB.Util, only: [empty_hash: 0]
  import YAB.Serializer, only: [pack: 1, unpack: 1]
  import YAB.Hasher, only: [hash: 1]

  alias YAB.{
    Block,
    Transaction,
    MerkleTree,
    Validator,
    BlockHeader,
    SignedTransaction
  }

  @type account_balances :: MerkleTree.t()
  @type account_error_reason :: :invalid_source_account | :low_balance

  @spec build_candidate(Block.t(), binary(), account_balances(), [SignedTransaction.t()]) ::
          {:ok, Block.t(), account_balances()} | {:error, block_validation_error}
  def build_candidate(latest_block, miner_account, accounts, transactions) do
    candidate =
      Block.candidate(
        miner_account: miner_account,
        prev_block_hash: hash(pack(latest_block)),
        transactions: transactions,
        chain_root_hash: MerkleTree.root_hash(accounts)
      )

    case validate_block(latest_block, accounts, candidate) do
      {:ok, new_account_balances} ->
        {:ok, candidate, new_account_balances}

      {:error, _} = error ->
        error
    end
  end

  @spec update_accounts(account_balances(), [Transaction.t()]) ::
          {:ok, account_balances()} | {:error, account_error_reason()}
  defp update_accounts(initial_accounts, transactions) do
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

  @spec apply_transaction_to_accounts(account_balances(), Transaction.t()) ::
          {:ok, account_balances()} | {:error, account_error_reason()}
  defp apply_transaction_to_accounts(
         account_balances,
         %Transaction{
           amount: amount,
           from_account: from_account,
           to_account: to_account
         }
       ) do
    case MerkleTree.lookup(account_balances, from_account) do
      nil ->
        {:error, :invalid_source_account}

      from_balance_bin ->
        from_balance = unpack(from_balance_bin)

        if amount > from_balance do
          {:error, :low_balance}
        else
          new_balances =
            account_balances
            |> MerkleTree.put(from_account, pack(from_balance - amount))
            |> add_to_account(to_account, amount)

          {:ok, new_balances}
        end
    end
  end

  @spec add_to_account(account_balances(), binary(), integer()) :: account_balances()
  defp add_to_account(accounts, to_account, amount)
       when is_binary(to_account) and is_integer(amount) do
    MerkleTree.update(
      accounts,
      to_account,
      pack(amount),
      &pack(unpack(&1) + amount)
    )
  end

  @type block_validation_error :: :invalid_transaction | :invalid_prev_block_hash

  @spec validate_block(Block.t(), account_balances, Block.t()) ::
          {:ok, account_balances()} | {:error, block_validation_error}
  defp validate_block(
         latest_block,
         accounts,
         %Block{
           transactions: transactions,
           header: %BlockHeader{
             previous_hash: previous_hash,
             chain_root_hash: chain_root_hash,
             transactions_root_hash: transactions_root_hash
           }
         }
       ) do
    latest_block_hash = hash(pack(latest_block))

    with [coinbase_transaction | transactions_without_coinbase] <- transactions,
         {:ok, %{miner: miner_account, reward: reward}} <-
           validate_coinbase_transaction(coinbase_transaction),
         :ok <- validate_transaction_signatures(transactions_without_coinbase),
         {:ok, new_account_balances} <-
           update_accounts(accounts, Enum.map(transactions_without_coinbase, & &1.transaction)) do
      cond do
        latest_block_hash != previous_hash ->
          {:error, :invalid_prev_block_hash}

        chain_root_hash != MerkleTree.root_hash(accounts) ->
          {:error, :invalid_chain_root_hash}

        Validator.hash_transactions(transactions) != transactions_root_hash ->
          {:error, :invalid_transactions_root_hash}

        true ->
          new_accounts_with_reward =
            new_account_balances
            |> add_to_account(miner_account, reward)

          {:ok, new_accounts_with_reward}
      end
    else
      {:error, _} = error ->
        error
    end
  end

  @spec validate_coinbase_transaction(SignedTransaction.t()) ::
          {:ok, %{miner: binary(), reward: integer()}}
  defp validate_coinbase_transaction(%SignedTransaction{
         signature: empty_hash(),
         transaction: %{from_account: empty_hash(), to_account: miner_account, amount: amount}
       }) do
    {:ok, %{miner: miner_account, reward: amount}}
  end

  defp validate_coinbase_transaction(_) do
    {:error, :invalid_coinbase_transaction}
  end

  @spec validate_transaction_signatures([Transaction.t()]) :: :ok | {:error, :invalid_transaction}
  defp validate_transaction_signatures(transactions) do
    if Enum.all?(transactions, &SignedTransaction.signature_valid?/1) do
      :ok
    else
      {:error, :invalid_transaction}
    end
  end
end
